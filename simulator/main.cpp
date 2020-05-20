#import "Vics32_tb.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <SDL.h>

#include <fstream>
#include <iterator>
#include <vector>
#include <iostream>

/*
 This is currently a minimal simulator for showing the video output.

 TODO:
    - Restore VCD dumping with appropriate trigger conditions
    - As more functionality is added, extract various function blocks to separate files
 */

// Current simulation time (64-bit unsigned)
vluint64_t main_time = 0;
// Called by $time in Verilog
double sc_time_stamp() {
    return main_time;  // Note does conversion to real, to match SystemC
}

int main(int argc, const char * argv[]) {
    Verilated::traceEverOn(true);
    Verilated::commandArgs(argc, argv);

    std::vector<unsigned char> cpu_program;

    // expecting the test program as first argument for now

    if (argc < 2) {
        std::cout << "Usage: ics32-sim <test-program>" << std::endl;
        return 1;
    }

    // 1. load test program...

    auto cpu_program_path = argv[1];
    std::ifstream cpu_program_stream(cpu_program_path, std::ios::binary);
    if (cpu_program_stream.ios_base::fail()) {
        std::cout << "Failed to open file: " << cpu_program_path << std::endl;
        return 1;
    }

    cpu_program = std::vector<unsigned char>(std::istreambuf_iterator<char>(cpu_program_stream), {});

    // ...into the flash where it will be loaded during IPL

    const auto flash_user_base = 0x100000;

    Vics32_tb *tb = new Vics32_tb;
    VerilatedVcdC *trace = new VerilatedVcdC;

    auto cpu_ram0 = tb->ics32_tb__DOT__ics32__DOT__cpu_ram__DOT__cpu_ram_0__DOT__mem;
    auto cpu_ram1 = tb->ics32_tb__DOT__ics32__DOT__cpu_ram__DOT__cpu_ram_1__DOT__mem;
    for (uint16_t i = 0; i < cpu_program.size() / 4; i++) {
        cpu_ram0[i * 2] = cpu_program[i * 4] | cpu_program[i * 4 + 1] << 8;
        cpu_ram1[i * 2 + 1] = cpu_program[i * 4 + 2] | cpu_program[i * 4 + 3] << 8;
    }

    auto flash = tb->ics32_tb__DOT__sim_flash__DOT__memory;
    std::copy(cpu_program.begin(), cpu_program.end(), &flash[flash_user_base]);

    // 2. present an SDL window to simulate VGA output

    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        std::cout << "SDL_Init() failed: " << SDL_GetError() << std::endl;
        return 1;
    }

    // 848x480 is assumed (smaller video modes will still appear correctly)

    const auto active_width = 848;
    const auto offscreen_width = 240;
    const auto total_width = active_width + offscreen_width;

    const auto active_height = 480;
    const auto offscreen_height = 37;
    const auto total_height = active_height + offscreen_height;

    auto window = SDL_CreateWindow(
       "ics32-sim",
       SDL_WINDOWPOS_CENTERED,
       SDL_WINDOWPOS_CENTERED,
       total_width,
       total_height,
       SDL_WINDOW_SHOWN
   );

    auto renderer = SDL_CreateRenderer(window, -1, 0);
    SDL_RenderSetScale(renderer, 1, 1);

    int current_x = 0;
    int current_y = 0;
    bool even_frame = true;

    const bool should_trace = false;

    if (should_trace) {
        tb->trace(trace, 99);
        trace->open("/Users/dan.rodrigues/Documents/ics.vcd");
    }

    while (!Verilated::gotFinish()) {
        // clock tick
        tb->ics32_tb__DOT__ics32__DOT__pll__DOT__clk_2x_r = 1;
        tb->eval();
        trace->dump(main_time);
        main_time++;

        tb->ics32_tb__DOT__ics32__DOT__pll__DOT__clk_2x_r = 0;
        tb->eval();
        trace->dump(main_time);
        main_time++;

        // render current VGA output pixel
        SDL_SetRenderDrawColor(renderer, tb->vga_r << 4, tb->vga_g << 4, tb->vga_b << 4, 255);
        SDL_RenderDrawPoint(renderer, current_x, current_y);
        current_x++;

        // note the sync signals here are NOT the VGA ones (those are vga_hsync / vga_vsync)
        // these are single-cycle strobes that are asserted only at the very end of a line (or frame)

        if (tb->hsync) {
            current_x = 0;
            current_y++;
        }

        if (tb->vsync) {
            current_y = 0;
            even_frame = !even_frame;

            SDL_RenderPresent(renderer);
            SDL_SetRenderDrawColor(renderer, even_frame ? 127 : 0, 0, 0, 255);
            SDL_RenderClear(renderer);
        }
        
        SDL_Event e;
        SDL_PollEvent(&e);

        if (e.type == SDL_QUIT) {
            break;
        }
    };

    tb->final();
    trace->close();

    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}
