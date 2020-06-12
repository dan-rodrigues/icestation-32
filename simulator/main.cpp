#include <SDL.h>

#include <fstream>
#include <iterator>
#include <vector>
#include <iostream>
#include <memory>

#include "VerilatorSimulation.hpp"

//#define SIM_IMPL VerilatorSimulation

int main(int argc, const char * argv[]) {
    SIM_IMPL sim;
    sim.forward_cmd_args(argc, argv);

    std::vector<uint8_t> cpu_program;

    // expecting the test program as first argument for now

    if (argc < 2) {
        std::cout << "Usage: ics32-sim <test-program>" << std::endl;
        return EXIT_SUCCESS;
    }

    // 1. load test program...

    auto cpu_program_path = argv[1];

    std::ifstream cpu_program_stream(cpu_program_path, std::ios::binary);
    if (cpu_program_stream.fail()) {
        std::cerr << "Failed to open file: " << cpu_program_path << std::endl;
        return EXIT_FAILURE;
    }

    cpu_program = std::vector<uint8_t>(std::istreambuf_iterator<char>(cpu_program_stream), {});

    if (cpu_program.size() % 4) {
        std::cerr << "Binary has irregular size: " << cpu_program.size() << std::endl;
        return EXIT_FAILURE;
    }

    sim.preload_cpu_program(cpu_program);

    // 2. present an SDL window to simulate video output

    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        std::cerr << "SDL_Init() failed: " << SDL_GetError() << std::endl;
        return EXIT_FAILURE;
    }

    // 848x480 is assumed (smaller video modes will still appear correctly)

    const auto active_width = 848;
    const auto offscreen_width = 240;
    const auto total_width = active_width + offscreen_width;

    const auto active_height = 480;
    const auto offscreen_height = 37;
    const auto total_height = active_height + offscreen_height;

    auto window = SDL_CreateWindow(
       "ics32-sim (verilator)",
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

    int current_x = 0;
    int current_y = 0;
    bool even_frame = true;

#if VM_TRACE
    sim.trace();
#endif

    bool vga_hsync_previous = false;
    bool vga_vsync_previous = false;

    sim.clk_1x = 0;
    sim.clk_2x = 0;

    uint64_t time = 0;

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

        auto round_color = [] (uint8_t component) {
            return component | component << 4;
        };

        // render current VGA output pixel
        SDL_SetRenderDrawColor(renderer, round_color(sim.r()), round_color(sim.g()), round_color(sim.b()), 255);
        SDL_RenderDrawPoint(renderer, current_x, current_y);
        current_x++;

        if (sim.hsync() && !vga_hsync_previous) {
            current_x = 0;
            current_y++;
        }

        vga_hsync_previous = sim.hsync();

        if (sim.vsync() && !vga_vsync_previous) {
            current_y = 0;
            even_frame = !even_frame;

            SDL_RenderPresent(renderer);
            SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
            SDL_RenderClear(renderer);

            // input test (using mocked 3-button setup as the iCEBreaker)
            SDL_PumpEvents();
            const Uint8 *state = SDL_GetKeyboardState(NULL);

            sim.button_1 = state[SDL_SCANCODE_LEFT];
            sim.button_2 = state[SDL_SCANCODE_RSHIFT];
            sim.button_3 = state[SDL_SCANCODE_RIGHT];
        }

        vga_vsync_previous = sim.vsync();

        // exit checking
        SDL_Event e;
        SDL_PollEvent(&e);

        if (e.type == SDL_QUIT) {
            break;
        }
    };

    sim.final();

    SDL_DestroyWindow(window);
    SDL_Quit();

    return EXIT_SUCCESS;
}
