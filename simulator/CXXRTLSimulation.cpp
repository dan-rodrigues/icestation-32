#include "CXXRTLSimulation.hpp"

void CXXRTLSimulation::preload_cpu_program(const std::vector<uint8_t> &program) { 
    auto & cpu_ram0 = top.memory_p_ics32_2e_cpu__ram_2e_cpu__ram__0_2e_mem;
    auto & cpu_ram1 = top.memory_p_ics32_2e_cpu__ram_2e_cpu__ram__1_2e_mem;

    size_t flash_user_base = 0x100000; // !
    auto & flash = top.memory_p_sim__flash_2e_memory;

    size_t ipl_load_length = std::min((size_t)0x20000, program.size());

    for (size_t i = 0; i < ipl_load_length / 4; i++) {
        uint16_t low_word = program[i * 4] | program[i * 4 + 1] << 8;
        uint16_t high_word = program[i * 4 + 2] | program[i * 4 + 3] << 8;

        cpu_ram0[i] = value<16>{low_word};
        cpu_ram1[i] = value<16>{high_word};

        size_t flash_base = flash_user_base + i * 4;

        flash[flash_base + 0] = value<8>{(uint8_t)(low_word & 0xff)};
        flash[flash_base + 1] = value<8>{(uint8_t)(low_word >> 8)};
        flash[flash_base + 2] = value<8>{(uint8_t)(high_word & 0xff)};
        flash[flash_base + 3] = value<8>{(uint8_t)(high_word >> 8)};
    }
}

uint8_t CXXRTLSimulation::r() const {
    return top.p_vga__r.curr.data[0];
}

uint8_t CXXRTLSimulation::g() const { 
    return top.p_vga__g.curr.data[0];
}

uint8_t CXXRTLSimulation::b() const { 
    return top.p_vga__b.curr.data[0];
}

bool CXXRTLSimulation::hsync() const { 
    return top.p_vga__hsync.curr.data[0];
}

bool CXXRTLSimulation::vsync() const { 
    return top.p_vga__vsync.curr.data[0];
}

void CXXRTLSimulation::final() { 

}

bool CXXRTLSimulation::finished() const { 
    return false;
}

void CXXRTLSimulation::step(uint64_t time) { 
    top.p_clk__1x = value<1>{clk_1x};
    top.p_clk__2x = value<1>{clk_2x};

    top.p_btn__1 = value<1>{button_1};
    top.p_btn__2 = value<1>{button_2};
    top.p_btn__3 = value<1>{button_3};

    top.step();

//    tb->eval();

#if VCD_WRITE
//    vcd.sample(0);
#endif
}
