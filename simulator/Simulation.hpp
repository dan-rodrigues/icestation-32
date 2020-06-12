#ifndef Simulation_hpp
#define Simulation_hpp

#include <stdarg.h>
#include <vector>
#include <stdint.h>

class Simulation {
public:
    virtual ~Simulation() {}

    bool clk_1x = false, clk_2x = false;
    bool button_1 = false, button_2 = false, button_3 = false;

    virtual void preload_cpu_program(const std::vector<uint8_t> &program) = 0;
    virtual void step() = 0;

    virtual uint8_t r() const = 0;
    virtual uint8_t g() const = 0;
    virtual uint8_t b() const = 0;

    virtual bool hsync() const = 0;
    virtual bool vsync() const = 0;

    virtual void final() = 0;
};

#endif /* Simulation_hpp */
