#ifndef CXXRTLSimulation_hpp
#define CXXRTLSimulation_hpp

#include <fstream>
#include <ostream>

#include "Simulation.hpp"

#include "cxxrtl_sim.h"

#if VCD_WRITE
#include <backends/cxxrtl/cxxrtl_vcd.h>
#endif

class CXXRTLSimulation: public Simulation {

public:
    void forward_cmd_args(int argc, const char * argv[]) override {};

    void preload_cpu_program(const std::vector<uint8_t> &program) override;
    void set_flash(std::unique_ptr<SPIFlash>) override;
    void step(uint64_t time) override;

#if VCD_WRITE
    void trace(const std::string &filename) override;
#endif

    uint8_t r() const override;
    uint8_t g() const override;
    uint8_t b() const override;

    bool hsync() const override;
    bool vsync() const override;

    void final() override;

    bool finished() const override;

private:
    cxxrtl_design::p_ics32__tb top;
    std::unique_ptr<SPIFlash> flash;

#if VCD_WRITE
    cxxrtl::vcd_writer vcd;
    std::ofstream vcd_stream;

    void update_trace(uint64_t time);
#endif
};

#endif /* CXXRTLSimulation_hpp */
