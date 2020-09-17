#ifndef Simulation_hpp
#define Simulation_hpp

#include <stdarg.h>
#include <vector>
#include <stdint.h>

#include "QSPIFlashSim.hpp"

class Simulation {
    
public:
    static QSPIFlashSim default_flash;

    virtual ~Simulation() {}

    void operator = (Simulation const &s) = delete;

    bool clk_1x = false, clk_2x = false;
    bool button_user = false;
    bool button_1 = false, button_2 = false, button_3 = false;
    bool button_y = false, button_up = false, button_down = false;
    bool button_l = false, button_r = false;
    bool button_x = false, button_a = false;
    bool button_select = false, button_start = false;

    virtual void forward_cmd_args(int argc, const char * argv[]) = 0;
    
    virtual void preload_cpu_program(const std::vector<uint8_t> &program) = 0;
    virtual void step(uint64_t time) = 0;

#if VCD_WRITE
    virtual void trace(const std::string &filename) = 0;
#endif

    virtual uint8_t r() const = 0;
    virtual uint8_t g() const = 0;
    virtual uint8_t b() const = 0;

    virtual bool hsync() const = 0;
    virtual bool vsync() const = 0;

    virtual bool get_samples(int16_t *left, int16_t *right) = 0;

    virtual void final() = 0;

    virtual bool finished() const = 0;
};

#endif /* Simulation_hpp */
