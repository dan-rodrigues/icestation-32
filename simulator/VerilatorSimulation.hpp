#ifndef VerilatorSimulation_hpp
#define VerilatorSimulation_hpp

#include <memory>

#include "Simulation.hpp"
#include "obj_dir/Vics32_tb.h"

#if VCD_WRITE
#include <verilated_vcd_c.h>
#endif

class VerilatorSimulation: public Simulation {

public:
    VerilatorSimulation() : flash(Simulation::default_flash) {}

    void forward_cmd_args(int argc, const char * argv[]) override;

    void preload_cpu_program(const std::vector<uint8_t> &program) override;
    void step(uint64_t time) override;

#if VCD_WRITE
    void trace(const std::string &filename) override;
#endif

    uint8_t r() const override;
    uint8_t g() const override;
    uint8_t b() const override;

    bool hsync() const override;
    bool vsync() const override;

    bool get_samples(int16_t *left, int16_t *right) override;

    void final() override;

    bool finished() const override;
    
private:
    std::unique_ptr<Vics32_tb> tb = std::unique_ptr<Vics32_tb>(new Vics32_tb);
    QSPIFlashSim flash;

#if VCD_WRITE
    std::unique_ptr<VerilatedVcdC> tfp;
    void trace_update(uint64_t time);
#endif
};

#endif /* VerilatorSimulation_hpp */
