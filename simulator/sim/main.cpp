// TODO: proper header

#import "Vics32_tb.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <SDL.h>

#include <fstream>
#include <iterator>
#include <vector>
#include <iostream>

// Current simulation time (64-bit unsigned)
vluint64_t main_time = 0;
// Called by $time in Verilog
double sc_time_stamp() {
    return main_time;
}

int main(int argc, const char * argv[]) {
    Verilated::traceEverOn(true);
    Verilated::commandArgs(argc, argv);

    // 1. cpu test program
    std::vector<unsigned char> buffer;

    if (argc > 1) {
        std::ifstream input(argv[1], std::ios::binary );
        buffer = std::vector<unsigned char>(std::istreambuf_iterator<char>(input), {});
    } else {
        return 1;
    }

    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        return 1;
    }

    // window with appropriate width
    auto const window_total_width = 240 + 848;
    auto window = SDL_CreateWindow("Window",
                                   SDL_WINDOWPOS_CENTERED,
                                   SDL_WINDOWPOS_CENTERED,
                                   window_total_width,
                                   768,
                                   SDL_WINDOW_SHOWN
                                   );

    auto renderer = SDL_CreateRenderer(window, -1, 0);

    Vics32_tb *tb = new Vics32_tb;
    VerilatedVcdC *trace = new VerilatedVcdC;

    long ticks = 0;

    auto flash = tb->ics32_tb__DOT__sim_flash__DOT__memory;
    std::copy(buffer.begin(), buffer.end(), &flash[0x100000]);

    // assume locked pll
    tb->ics32_tb__DOT__ics32__DOT__pll_locked = 1;
    tb->eval();

    int currentx = 0;
    int currenty = 0;
    bool evenframe = true;

    SDL_RenderSetScale(renderer, 1, 1);

    // vga timing
    int lineClocks = 0;
    int frameClocks = 0;

    int vga_hclocks = 0;
    int vga_vclocks = 0;

    // !!!
    const bool shouldTrace = false;

    while(!Verilated::gotFinish()) {
        ticks++;

//        bool traceTrigger = true;
        bool traceTrigger = tb->ics32_tb__DOT__ics32__DOT__cpu_mem_ready;

        // trace condition
        if (shouldTrace && !trace->isOpen() && traceTrigger) {
            printf("starting trace...\n");

            tb->trace(trace, 99);
            trace->open("/Users/dan.rodrigues/hw/sandbox/trace/rv32-main.vcd");
        }

        tb->ics32_tb__DOT__ics32__DOT__pll__DOT__clk_2x_r = 1;
        tb->eval();
        trace->dump(main_time);
        main_time++;

        tb->ics32_tb__DOT__ics32__DOT__pll__DOT__clk_2x_r = 0;
        tb->eval();
        trace->dump(main_time);
        main_time++;

        // screen
        bool isSync = !tb->vga_hsync || !tb->vga_vsync;
        auto divisor = tb->vga_de ? 1 : 2;
        if (isSync) {
            SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
        } else {
            SDL_SetRenderDrawColor(renderer, tb->vga_r / divisor << 4, tb->vga_g / divisor << 4, tb->vga_b / divisor << 4, 255);
        }

        SDL_RenderDrawPoint(renderer, currentx, currenty);
        currentx++;

        lineClocks++;
        frameClocks++;

        if (tb->hsync) {
            currentx = 0;

            lineClocks = 0;

            currenty++;
        }

        // this might end the frame early but should have no impact on the below
        if (tb->vsync) {
            currenty = 0;
            evenframe = !evenframe;

            frameClocks = 0;

            SDL_RenderPresent(renderer);
            SDL_SetRenderDrawColor(renderer, evenframe ? 127 : 0, 0, 0, 255);
            SDL_RenderClear(renderer);
        }

        // TODO: VGA timing log

        if (tb->vga_hsync) {
            vga_hclocks += 1;
        } else {
            if (vga_hclocks > 0) {
                vga_hclocks = 0;
            }
        }

        if (tb->vga_vsync) {
            vga_vclocks += 1;
        } else {
            if (vga_vclocks > 0) {
                vga_vclocks = 0;
            }
        }
        
        SDL_Event e;
        SDL_PollEvent(&e);

        if (e.type == SDL_QUIT){
            break;
        }
    };

    tb->final();

    trace->close();

    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}
