#include <SDL.h>

#include <fstream>
#include <iterator>
#include <vector>
#include <iostream>
#include <memory>

#include "SPIFlash.hpp"

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

int main(int argc, const char * argv[]) {
    if (argc < 2) {
        std::cout << "Usage: <sim> <test-program>" << std::endl;
        return EXIT_SUCCESS;
    }

    // 1. load test program...

    auto cpu_program_path = argv[1];

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

    const size_t flash_user_base = 0x100000;
    const size_t flash_ipl_size = 0x10000;

    // prepare flash before initializing the core sim instance

    SPIFlash flash_sim;
    cpu_program.resize(flash_ipl_size);
    flash_sim.load(cpu_program, flash_user_base);
    Simulation::default_flash = flash_sim;

    SimulationImpl sim;
    sim.forward_cmd_args(argc, argv);
    sim.preload_cpu_program(cpu_program);

    // 2. present an SDL window to simulate video output

    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
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

    sim.clk_1x = 0;
    sim.clk_2x = 0;

    uint64_t time = 0;
    uint64_t previous_ticks = 0;

    const auto sdl_poll_interval = 10000;
    auto sdl_poll_counter = sdl_poll_interval;

    while (!sim.finished()) {
        // clock negedge
        sim.clk_2x = 0;
        sim.step(time);
        time++;

        // clock posedge
        sim.clk_2x = 1;
        sim.clk_1x = time & 2;
        sim.step(time);
        time++;

        const auto extend_color = [] (uint8_t component) {
            return component | component << 4;
        };

        // render current VGA output pixel
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

            // input test (using mocked 3-button setup as the iCEBreaker)
            SDL_PumpEvents();
            const Uint8 *state = SDL_GetKeyboardState(NULL);

            sim.button_1 = state[SDL_SCANCODE_LEFT];
            sim.button_2 = state[SDL_SCANCODE_RSHIFT];
            sim.button_3 = state[SDL_SCANCODE_RIGHT];

            // measure time spent to render frame
            uint64_t current_ticks = SDL_GetTicks();
            double delta = current_ticks - previous_ticks;
            auto fps_estimate = 1 / (delta / 1000.f);
            std::cout << "Frame drawn in: " << delta << "ms, " << fps_estimate << "fps" << std::endl;
            previous_ticks = current_ticks;
        }

        vga_vsync_previous = sim.vsync();

        // exit checking

        if (!(--sdl_poll_counter)) {
            SDL_Event e;
            SDL_PollEvent(&e);

            if (e.type == SDL_QUIT) {
                break;
            }

            sdl_poll_counter = sdl_poll_interval;
        }
    };

    sim.final();

    SDL_DestroyTexture(texture);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();

    std::free(pixels);

    return EXIT_SUCCESS;
}
