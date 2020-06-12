#include "VerilatorSimulation.hpp"

#include <assert.h>

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
    auto cpu_ram0 = tb->ics32_tb__DOT__ics32__DOT__cpu_ram__DOT__cpu_ram_0__DOT__mem;
    auto cpu_ram1 = tb->ics32_tb__DOT__ics32__DOT__cpu_ram__DOT__cpu_ram_1__DOT__mem;

    size_t ipl_load_length = std::min((size_t)0x20000, program.size());
    for (size_t i = 0; i < ipl_load_length / 4; i++) {
        cpu_ram0[i] = program[i * 4] | program[i * 4 + 1] << 8;
        cpu_ram1[i] = program[i * 4 + 2] | program[i * 4 + 3] << 8;
    }

    const size_t flash_user_base = 0x100000;
    auto flash = tb->ics32_tb__DOT__sim_flash__DOT__memory;

    std::copy(program.begin(), program.end(), &flash[flash_user_base]);
}

void VerilatorSimulation::step(uint64_t time) {
    main_time = time;

    tb->clk_1x = clk_1x;
    tb->clk_2x = clk_2x;

    tb->ics32_tb__DOT__ics32__DOT__btn1 = button_1;
    tb->ics32_tb__DOT__ics32__DOT__btn2 = button_2;
    tb->ics32_tb__DOT__ics32__DOT__btn3 = button_3;

    tb->eval();

#if VM_TRACE
    trace_update(time);
#endif
}

#if VM_TRACE

void VerilatorSimulation::trace_update(uint64_t time) {
    assert(tfp);
    tfp->dump((vluint64_t)time);
}

void VerilatorSimulation::trace() {
    Verilated::traceEverOn(true);

    const auto trace_path = "ics.vcd"; // !

    tfp = std::unique_ptr<VerilatedVcdC>(new VerilatedVcdC);

    tb->trace(tfp.get(), 99);
    tfp->open(trace_path);
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

#if VM_TRACE
    if (tfp) {
        tfp->close();
    }
#endif
}
