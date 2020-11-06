#include <SDL.h>

#include <fstream>
#include <iterator>
#include <vector>
#include <iostream>
#include <memory>
#include <getopt.h>
#include <limits>

#include "QSPIFlashSim.hpp"

#include "tinywav.h"

#ifdef SIM_VERILATOR

#include "VerilatorSimulation.hpp"
typedef VerilatorSimulation SimulationImpl;
const std::string title = "verilator";

#elif defined(SIM_CXXRTL)

#include "CXXRTLSimulation.hpp"
typedef CXXRTLSimulation SimulationImpl;
const std::string title = "cxxrtl";

#else

#error Expected one of SIM_VERILATOR or SIM_CXXRTL to be defined

#endif

// Audio:

#define AUDIO_SUPPORT

void audio_callback(void *userdata, Uint8 *stream, int len);
std::deque<int16_t> audio_callback_samples;

SDL_AudioDeviceID init_sdl_audio(void);
bool write_captured_audio(const std::string &path, const std::vector<int16_t> &samples);

int main(int argc, const char **argv) {
    if (argc < 2) {
        std::cout << "Usage: <sim> <test-program>" << std::endl;
        return EXIT_SUCCESS;
    }

    std::string wav_output_path = "";
    int64_t sim_cycles = std::numeric_limits<int64_t>::max();
    bool enable_audio_output = false;

    int opt = 0;
    while ((opt = getopt_long(argc, (char **)argv, "w:t:na", NULL, NULL)) != -1) {
        switch (opt) {
            case 'w':
#ifdef AUDIO_SUPPORT
            {
                wav_output_path = optarg;
                if (wav_output_path.empty()) {
                    std::cerr << "WAV output path must not be empty" << std::endl;
                    return EXIT_FAILURE;
                }
            } break;
#else
            std::cerr << "Can't enable WAV dumping (wasn't built with AUDIO_SUPPORT)" << std::endl;
            return EXIT_FAILURE;
#endif
            case 'a':
#ifdef AUDIO_SUPPORT
                enable_audio_output = true;
                break;
#else
                std::cerr << "Can't enable audio output (wasn't built with AUDIO_SUPPORT)" << std::endl;
                return EXIT_FAILURE;
#endif
            case 't':
                sim_cycles = strtol(optarg, NULL, 10);
                if (sim_cycles <= 0) {
                    std::cerr << "-t argument must be a non-zero positive integer" << std::endl;
                    return EXIT_FAILURE;
                }
            case '?':
                return EXIT_FAILURE;
        }
    }

#ifdef AUDIO_SUPPORT
    bool wav_output_required = !wav_output_path.empty();
    bool audio_capture_required = enable_audio_output || wav_output_required;
#else
    bool wav_output_required = false;
    bool audio_capture_required = false;
#endif

    // 1. Load test program...

    if (optind >= argc) {
        std::cerr << "Expected test program path after any options" << std::endl;
        return EXIT_FAILURE;
    }

    auto cpu_program_path = argv[optind];

    std::ifstream cpu_program_stream(cpu_program_path, std::ios::binary);
    if (cpu_program_stream.fail()) {
        std::cerr << "Failed to open file: " << cpu_program_path << std::endl;
        return EXIT_FAILURE;
    }

    std::vector<uint8_t> cpu_program(std::istreambuf_iterator<char>(cpu_program_stream), {});
    cpu_program_stream.close();

    if (cpu_program.size() % 4) {
        std::cerr << "Program has irregular size: " << cpu_program.size() << std::endl;
        return EXIT_FAILURE;
    }

    const size_t flash_user_base = 0x200000;
    const size_t flash_ipl_size = 0x10000;

    // Prepare flash before initializing the core sim instance

    QSPIFlashSim flash_sim;
    flash_sim.powered_down = true;
    flash_sim.enable_info_logging = false;

    if (cpu_program.size() < flash_ipl_size) {
        cpu_program.resize(flash_ipl_size);
    }

    flash_sim.load(cpu_program, flash_user_base);
    Simulation::default_flash = flash_sim;

    SimulationImpl sim;
    sim.forward_cmd_args(argc, argv);
    sim.preload_cpu_program(cpu_program);

    // 2. Present an SDL window to simulate video output

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) != 0) {
        std::cerr << "SDL_Init() failed: " << SDL_GetError() << std::endl;
        return EXIT_FAILURE;
    }

    // SDL defaults to Metal API on MacOS and is incredibly slow to run SDL_RenderPresent()
    // Hint to use OpenGL if possible
#if TARGET_OS_MAC
    SDL_SetHint(SDL_HINT_RENDER_DRIVER, "opengl");
#endif

    // 848x480 is assumed (smaller video modes will still appear correctly)

    const auto active_width = 848;
    const auto offscreen_width = 240;
    const auto total_width = active_width + offscreen_width;

    const auto active_height = 480;
    const auto offscreen_height = 37;
    const auto total_height = active_height + offscreen_height;

    auto window = SDL_CreateWindow(
       ("ics32-sim (" + title + ")").c_str(),
       SDL_WINDOWPOS_CENTERED,
       SDL_WINDOWPOS_CENTERED,
       total_width,
       total_height,
       SDL_WINDOW_SHOWN
   );

    auto renderer = SDL_CreateRenderer(window, -1, 0);
    SDL_RenderSetScale(renderer, 1, 1);
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);

    SDL_Texture *texture = SDL_CreateTexture(renderer,
        SDL_PIXELFORMAT_RGB24,
        SDL_TEXTUREACCESS_STATIC,
        total_width,
        total_height
    );

    const size_t rgb24_size = 3;
    uint8_t *pixels = (uint8_t *)std::calloc(total_width * total_height * rgb24_size, sizeof(uint8_t));
    assert(pixels);

    int current_x = 0;
    int current_y = 0;
    size_t pixel_index = 0;

#if VCD_WRITE
    sim.trace("ics.vcd");
#endif

    bool vga_hsync_previous = true;
    bool vga_vsync_previous = true;

    // Audio init

    SDL_AudioDeviceID audio_device_id = 0;
    if (enable_audio_output) {
        audio_device_id = init_sdl_audio();
    }

    sim.clk_1x = 0;
    sim.clk_2x = 0;

    uint64_t time = 0;
    uint64_t previous_ticks = 0;

    const auto sdl_poll_interval = 10000;
    auto sdl_poll_counter = sdl_poll_interval;

    std::vector<int16_t> audio_samples;

    while (!sim.finished() && (time / 2) < sim_cycles) {
        sim.clk_2x = 0;
        sim.step(time);
        time++;

        sim.clk_2x = 1;
        sim.clk_1x = time & 2;
        sim.step(time);
        time++;

        const auto extend_color = [] (uint8_t component) {
            return component | component << 4;
        };

        // Plot current output pixel
        bool active_display = sim.vsync() && sim.hsync();
        bool in_bounds = current_x < total_width && current_y < total_height;
        if (active_display && in_bounds) {
            pixels[pixel_index++] = extend_color(sim.r());
            pixels[pixel_index++] = extend_color(sim.g());
            pixels[pixel_index++] = extend_color(sim.b());
        } else if (active_display) {
            std::cout << "Attempted to draw out of bounds pixel: (" << current_x << ", " << current_y << ")" << std::endl;
        }

        current_x++;

        const auto update_pixel_index = [&] () {
            pixel_index = current_y * total_width * rgb24_size;
        };

        if (!sim.hsync()) {
            current_x = 0;
            update_pixel_index();
        }

        if (sim.hsync() && !vga_hsync_previous) {
            current_y++;
            update_pixel_index();
        }

        vga_hsync_previous = sim.hsync();

        if (!sim.vsync()) {
            current_y = 0;
            update_pixel_index();
        }

        if (sim.vsync() && !vga_vsync_previous) {
            const auto stride = total_width * rgb24_size;
            SDL_UpdateTexture(texture, NULL, pixels, stride);
            SDL_RenderCopy(renderer, texture, NULL, NULL);
            SDL_RenderPresent(renderer);

            // Simulate gamepad input with keyboard

            SDL_PumpEvents();
            const Uint8 *state = SDL_GetKeyboardState(NULL);

            sim.button_user = state[SDL_SCANCODE_LSHIFT];
            sim.button_1 = state[SDL_SCANCODE_RIGHT];
            sim.button_2 = state[SDL_SCANCODE_RSHIFT];
            sim.button_3 = state[SDL_SCANCODE_LEFT];

            sim.button_up = state[SDL_SCANCODE_UP];
            sim.button_down = state[SDL_SCANCODE_DOWN];

            sim.button_l = state[SDL_SCANCODE_Q];
            sim.button_r = state[SDL_SCANCODE_W];

            sim.button_x = state[SDL_SCANCODE_A];
            sim.button_a = state[SDL_SCANCODE_S];
            sim.button_y = state[SDL_SCANCODE_Z];

            sim.button_start = state[SDL_SCANCODE_E];
            sim.button_select = state[SDL_SCANCODE_R];
            
            // Measure time spent to render frame

            uint64_t current_ticks = SDL_GetTicks();
            double delta = current_ticks - previous_ticks;
            auto fps_estimate = 1 / (delta / 1000.f);
            std::cout << "Frame drawn in: " << delta << "ms, " << fps_estimate << "fps" << std::endl;
            previous_ticks = current_ticks;
        }

        vga_vsync_previous = sim.vsync();

        // Audio capture (optional)

        if (audio_capture_required) {
            int16_t audio_left, audio_right;
            if (sim.get_samples(&audio_left, &audio_right)) {
                if (enable_audio_output) {
                    audio_callback_samples.push_back(audio_left);
                    audio_callback_samples.push_back(audio_right);
                }

                if (wav_output_required) {
                    audio_samples.push_back(audio_left);
                    audio_samples.push_back(audio_right);
                }
            }
        }

        // Exit check

        if (!(--sdl_poll_counter)) {
            SDL_Event e;
            if (SDL_PollEvent(&e) && (e.type == SDL_QUIT)) {
                std::cout << "Quitting.." << "\n";
                break;
            }

            sdl_poll_counter = sdl_poll_interval;
        }
    };

    sim.final();

    if (audio_device_id >= 2) {
        SDL_CloseAudioDevice(audio_device_id);
    }

    SDL_DestroyTexture(texture);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();

    std::free(pixels);

    if (wav_output_required) {
        if (!write_captured_audio(wav_output_path, audio_samples)) {
            return EXIT_FAILURE;
        }
    }

    return EXIT_SUCCESS;
}

// Audio related functions:

bool write_captured_audio(const std::string &path, const std::vector<int16_t> &samples) {
    TinyWav tw;
    auto open_status = tinywav_open_write(
        &tw,
        2,
        44100,
        TW_INT16,
        TW_INTERLEAVED,
        path.c_str()
    );

    if (open_status) {
        std::cerr << "Failed to open WAV file for writing: " << path << std::endl;
        return false;
    }

    // tinywav expects floats regardless of the encoded format
    std::vector<float> float_samples;
    for (auto sample : samples) {
        float_samples.push_back(((float)sample) / 32767);
    }

    tinywav_write_f(&tw, &float_samples[0], (int)(float_samples.size() / 2));
    tinywav_close_write(&tw);

    return true;
}

SDL_AudioDeviceID init_sdl_audio() {
    SDL_AudioSpec want, have;
    SDL_AudioDeviceID dev;

    SDL_memset(&want, 0, sizeof(want));
    want.freq = 44100;
    want.format = AUDIO_S16;
    want.channels = 2;
    want.samples = 4096;
    want.callback = audio_callback;

    dev = SDL_OpenAudioDevice(NULL, 0, &want, &have, 0);
    if (dev == 0) {
        std::cerr << "SDL_OpenAudioDevice() failed: " << SDL_GetError() << std::endl;
    } else {
        if (have.format != want.format) {
            std::cerr << "Could not open device with SDL AUDIO_S16 format" << std::endl;
        }

        SDL_PauseAudioDevice(dev, 0);
    }

    return dev;
}

// SDL audio callback:

void audio_callback(void *userdata, Uint8 *stream, int len) {
    std::memset(stream, 0, len);

    size_t length = std::min((size_t)len / 4, audio_callback_samples.size() / 2);
    int16_t *samples = (int16_t *)stream;
    std::copy(audio_callback_samples.cbegin(), audio_callback_samples.cbegin() + length, samples);
    audio_callback_samples.erase(audio_callback_samples.cbegin(), audio_callback_samples.cbegin() + length);

    std::cout << "Audio: copied " << length << " stereo samples" << "\n";
}
