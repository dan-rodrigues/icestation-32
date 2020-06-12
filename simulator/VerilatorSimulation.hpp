#ifndef VerilatorSimulation_hpp
#define VerilatorSimulation_hpp

#include "obj_dir/Vics32_tb.h"
#include "Simulation.hpp"

#include <memory>

class VerilatorSimulation: Simulation {

public:
    void preload_cpu_program(const std::vector<uint8_t> &program) override;

//private:
    std::unique_ptr<Vics32_tb> tb = std::unique_ptr<Vics32_tb>(new Vics32_tb);
};

#endif /* VerilatorSimulation_hpp */
