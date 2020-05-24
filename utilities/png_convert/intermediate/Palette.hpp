#ifndef Palette_hpp
#define Palette_hpp

#include <stdint.h>
#include <vector>

class Palette {

public:
    Palette();
    Palette(std::vector<uint32_t> rgba32_palette);

    std::vector<uint32_t> rgba32_palette;

    std::vector<uint16_t> ics_palette();
};

#endif /* Palette_hpp */
