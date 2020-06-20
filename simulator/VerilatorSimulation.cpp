#include "VerilatorSimulation.hpp"

#include <assert.h>

#include "Vics32_tb__Syms.h"

// verilator specific: called by $time in Verilog
static vluint64_t main_time = 0;
double sc_time_stamp() {
    return main_time;
}

void VerilatorSimulation::forward_cmd_args(int argc, const char *argv[]) {
    Verilated::commandArgs(argc, argv);
}

bool VerilatorSimulation::finished() const {
    return Verilated::gotFinish();
}

void VerilatorSimulation::preload_cpu_program(const std::vector<uint8_t> &program) {
    auto ram_0 = tb->ics32_tb->ics32->cpu_ram->cpu_ram_0->mem;
    auto ram_1 = tb->ics32_tb->ics32->cpu_ram->cpu_ram_1->mem;

    size_t ipl_load_length = std::min((size_t)0x20000, program.size());
    for (size_t i = 0; i < ipl_load_length / 4; i++) {
        ram_0[i] = program[i * 4] | program[i * 4 + 1] << 8;
        ram_1[i] = program[i * 4 + 2] | program[i * 4 + 3] << 8;
    }
}

void VerilatorSimulation::step(uint64_t time) {
    main_time = time;

    tb->clk_1x = clk_1x;
    tb->clk_2x = clk_2x;

    tb->btn_1 = button_1;
    tb->btn_2 = button_2;
    tb->btn_3 = button_3;

    auto flash_bb = tb->ics32_tb->flash;
    uint8_t io = flash.update(flash_bb->csn, flash_bb->clk, flash_bb->in);
    flash.check_conflicts(flash_bb->in_en);

    tb->eval();
    flash_bb->out = io;

#if VCD_WRITE
    trace_update(time);
#endif
}

#if VCD_WRITE

void VerilatorSimulation::trace_update(uint64_t time) {
    assert(tfp);
    tfp->dump((vluint64_t)time);
}

void VerilatorSimulation::trace(const std::string &filename) {
    Verilated::traceEverOn(true);

    tfp = std::unique_ptr<VerilatedVcdC>(new VerilatedVcdC);

    tb->trace(tfp.get(), 99);
    tfp->open(filename.c_str());
    assert(tfp->isOpen());
}

#endif

uint8_t VerilatorSimulation::r() const {
    return tb->vga_r;
}

uint8_t VerilatorSimulation::g() const {
    return tb->vga_g;
}

uint8_t VerilatorSimulation::b() const {
    return tb->vga_b;
}

bool VerilatorSimulation::hsync() const {
    return tb->vga_hsync;
}

bool VerilatorSimulation::vsync() const {
    return tb->vga_vsync;
}

void VerilatorSimulation::final() {
    tb->final();

#if VCD_WRITE
    if (tfp) {
        tfp->close();
    }
#endif
}
