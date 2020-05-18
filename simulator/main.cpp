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
    - Restore VCD dumping with appropraite trigger conditions
    - As more functionality is added, extract various function blocks to separate files
 */

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

    // assume locked pll to immediate run the reset generator
    tb->ics32_tb__DOT__ics32__DOT__pll_locked = 1;
    tb->eval();

    int current_x = 0;
    int current_y = 0;
    bool even_frame = true;

    while (!Verilated::gotFinish()) {
        // clock tick
        tb->ics32_tb__DOT__ics32__DOT__pll__DOT__clk_2x_r = 1;
        tb->eval();
        tb->ics32_tb__DOT__ics32__DOT__pll__DOT__clk_2x_r = 0;
        tb->eval();

        // render current VGA output pixel
        SDL_SetRenderDrawColor(renderer, tb->vga_r << 4, tb->vga_g << 4, tb->vga_b << 4, 255);
        SDL_RenderDrawPoint(renderer, current_x, current_y);
        current_x++;

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

        if (e.type == SDL_QUIT){
            break;
        }
    };

    tb->final();

    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}
