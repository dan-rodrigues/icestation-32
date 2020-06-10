// (cleanup simulator directory structure if there's going to be 2 sim options)
#include "../../hardware/cxxrtl_sim.cpp"

#include <stdio.h>
#include <stdarg.h>

#include <numeric>
#include <iostream>
#include <vector>
#include <fstream>
#include <ostream>

#include <SDL.h>

int main(int argc, const char * argv[]) {
    cxxrtl_design::p_ics32__tb top;

    // load program into user flash

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

    // ...into both flash (for software use) and CPU RAM (so that IPL can be skipped)

    auto & cpu_ram0 = top.memory_p_ics32_2e_cpu__ram_2e_cpu__ram__0_2e_mem;
    auto & cpu_ram1 = top.memory_p_ics32_2e_cpu__ram_2e_cpu__ram__1_2e_mem;

    size_t flash_user_base = 0x100000;
    auto & flash = top.memory_p_sim__flash_2e_memory;

    size_t ipl_load_length = std::min((size_t)0x20000, cpu_program.size());

    for (uint16_t i = 0; i < ipl_load_length / 4; i++) {
        uint16_t low_word = cpu_program[i * 4] | cpu_program[i * 4 + 1] << 8;
        uint16_t high_word = cpu_program[i * 4 + 2] | cpu_program[i * 4 + 3] << 8;

        cpu_ram0[i] = value<16>{low_word};
        cpu_ram1[i] = value<16>{high_word};

        size_t flash_base = flash_user_base + i * 4;

        flash[flash_base + 0] = value<8>{(uint8_t)(low_word & 0xff)};
        flash[flash_base + 1] = value<8>{(uint8_t)(low_word >> 8)};
        flash[flash_base + 2] = value<8>{(uint8_t)(high_word & 0xff)};
        flash[flash_base + 3] = value<8>{(uint8_t)(high_word >> 8)};
    }

    // video setup

    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        std::cerr << "SDL_Init() failed: " << SDL_GetError() << std::endl;
        return EXIT_FAILURE;
    }

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

    bool vga_hsync_previous;
    bool vga_vsync_previous;
    bool even_frame = true;

    // vcd

    cxxrtl::debug_items debug;
    top.debug_info(debug);

    cxxrtl::vcd_writer vcd;
    vcd.timescale(1, "ns");

    std::vector<std::string> filter_names = {"pico", "clk", "reset"};

    vcd.add(debug, [=](const std::string &name, const debug_item &item) {
        for (auto filter_name : filter_names) {
            if (name.find(filter_name) != std::string::npos) {
                return true;
            }
        }

        return false;
    });

    top.p_clk__12m = value<1>{0u};
    top.step();
    vcd.sample(0);

    // adjust accordingly
    int duration = 500;
    int steps = 0;
    bool log = false;


    std::ofstream vcd_stream("sim.vcd", std::ios::out);

    while (steps++ < duration) {
        top.p_clk__12m = value<1>{0u};
        top.step();
        vcd.sample(steps * 2);

        top.p_clk__12m = value<1>{1u};
        top.step();
        vcd.sample(steps * 2 + 1);

        // vcd write

        vcd_stream << vcd.buffer;
        vcd.buffer.clear();

        // quick and dirty logs for now
        if (log) {
            std::cout << "clk1x: " << top.p_ics32_2e_pll_2e_clk__1x__r << "\n";
            std::cout << "clk2x: " << top.p_vga__clk << "\n";

            std::cout << "memaddr: " << top.p_ics32_2e_pico_2e_mem__addr << "\n";

            std::cout << "pc: " << top.p_ics32_2e_pico_2e_reg__pc << "\n";
            std::cout << "memaddr: " << top.p_ics32_2e_pico_2e_mem__addr << "\n";
            std::cout << "memvalid: " << top.p_ics32_2e_pico_2e_mem__valid << "\n";

            std::cout << "reset out2x: " << top.p_ics32_2e_reset__generator_2e_reset__2x << "\n";

            std::cout << "reset ctr: " << top.p_ics32_2e_reset__generator_2e_counter << "\n";
            std::cout << "reset core: " << top.p_ics32_2e_reset__generator_2e_reset << "\n";

            std::cout << "trap: " << top.p_ics32_2e_pico_2e_trap << "\n";
        }

        auto round_color = [] (uint8_t component) {
            return component | component << 4;
        };

        // render current VGA output pixel
        SDL_SetRenderDrawColor(renderer, round_color(top.p_vga__r.curr.data[0]), round_color(top.p_vga__g.curr.data[0]), round_color(top.p_vga__b.curr.data[0]), 255);
        SDL_RenderDrawPoint(renderer, current_x, current_y);
        current_x++;

        if (top.p_vga__hsync.curr.data[0] && !vga_hsync_previous) {
            current_x = 0;
            current_y++;

            std::cout << "line c: " << current_y << "\n";
            std::cout << "pc: " << top.p_ics32_2e_pico_2e_reg__pc << "\n";
            std::cout << "trap: " << top.p_ics32_2e_pico_2e_trap << "\n";
        }

        vga_hsync_previous = top.p_vga__hsync.curr.data[0];

        if (top.p_vga__vsync.curr.data[0] && !vga_vsync_previous) {
            current_y = 0;
            even_frame = !even_frame;

            SDL_RenderPresent(renderer);
            SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
            SDL_RenderClear(renderer);

            // input test (using mocked 3-button setup as the iCEBreaker)
            SDL_PumpEvents();
            const Uint8 *state = SDL_GetKeyboardState(NULL);

            //            top.p_btn3 = value<1>(state[SDL_SCANCODE_LEFT]);
            //            top.p_btn2 = value<1>(state[SDL_SCANCODE_RSHIFT]);
            //            top.p_btn1 = value<1>(state[SDL_SCANCODE_RIGHT]);
        }

        vga_vsync_previous = top.p_vga__vsync.curr.data[0];

        // exit checking
        SDL_Event e;
        SDL_PollEvent(&e);

        if (e.type == SDL_QUIT) {
            break;
        }
    }

    vcd_stream.close();

    return EXIT_SUCCESS;
}
