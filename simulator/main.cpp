#include <verilated.h>

#if VM_TRACE
#include <verilated_vcd_c.h>
#endif

#include <SDL.h>

#include <fstream>
#include <iterator>
#include <vector>
#include <iostream>
#include <memory>

#include "Vics32_tb.h"

// Current simulation time (64-bit unsigned)
vluint64_t main_time = 0;
// Called by $time in Verilog
double sc_time_stamp() {
    return main_time;
}

int main(int argc, const char * argv[]) {
    Verilated::commandArgs(argc, argv);

#if VM_TRACE
    Verilated::traceEverOn(true);
#endif

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

    std::unique_ptr<Vics32_tb> tb(new Vics32_tb);

    // ...into both flash (for software use) and CPU RAM (so that IPL can be skipped)

    auto cpu_ram0 = tb->ics32_tb__DOT__ics32__DOT__cpu_ram__DOT__cpu_ram_0__DOT__mem;
    auto cpu_ram1 = tb->ics32_tb__DOT__ics32__DOT__cpu_ram__DOT__cpu_ram_1__DOT__mem;

    size_t ipl_load_length = std::min((size_t)0x10000, cpu_program.size());
    for (uint16_t i = 0; i < ipl_load_length / 4; i++) {
        cpu_ram0[i] = cpu_program[i * 4] | cpu_program[i * 4 + 1] << 8;
        cpu_ram1[i] = cpu_program[i * 4 + 2] | cpu_program[i * 4 + 3] << 8;
    }

    const auto flash_user_base = 0x100000;
    auto flash = tb->ics32_tb__DOT__sim_flash__DOT__memory;

    std::copy(cpu_program.begin(), cpu_program.end(), &flash[flash_user_base]);

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
       "ics32-sim",
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
    const auto trace_path = "ics.vcd";

    std::unique_ptr<VerilatedVcdC> tfp(new VerilatedVcdC);

    tb->trace(tfp.get(), 99);
    tfp->open(trace_path);
#endif

    bool vga_hsync_previous = false;
    bool vga_vsync_previous = false;

    while (!Verilated::gotFinish()) {
        // clock posedge
        tb->ics32_tb__DOT__ics32__DOT__pll__DOT__clk_2x_r = 1;
        tb->eval();
#if VM_TRACE
        tfp->dump(main_time);
#endif
        main_time++;

        // clock negedge
        tb->ics32_tb__DOT__ics32__DOT__pll__DOT__clk_2x_r = 0;
        tb->eval();
#if VM_TRACE
        tfp->dump(main_time);
#endif
        main_time++;

        auto round_color = [] (uint8_t component) {
            return component | component << 4;
        };

        // render current VGA output pixel
        SDL_SetRenderDrawColor(renderer, round_color(tb->vga_r), round_color(tb->vga_g), round_color(tb->vga_b), 255);
        SDL_RenderDrawPoint(renderer, current_x, current_y);
        current_x++;

        if (tb->vga_hsync && !vga_hsync_previous) {
            current_x = 0;
            current_y++;
        }

        vga_hsync_previous = tb->vga_hsync;

        if (tb->vga_vsync && !vga_vsync_previous) {
            current_y = 0;
            even_frame = !even_frame;

            SDL_RenderPresent(renderer);
            SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
            SDL_RenderClear(renderer);
        }

        vga_vsync_previous = tb->vga_vsync;
        
        SDL_Event e;
        SDL_PollEvent(&e);

        if (e.type == SDL_QUIT) {
            break;
        }
    };

    tb->final();

#if VM_TRACE
    tfp->close();
#endif

    SDL_DestroyWindow(window);
    SDL_Quit();

    return EXIT_SUCCESS;
}
