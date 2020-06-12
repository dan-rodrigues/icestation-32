#ifndef Simulation_hpp
#define Simulation_hpp

#include <stdarg.h>
#include <vector>
#include <stdint.h>

class Simulation {
public:
    virtual ~Simulation() {}

    virtual void preload_cpu_program(const std::vector<uint8_t> &program) = 0;
};

#endif /* Simulation_hpp */
