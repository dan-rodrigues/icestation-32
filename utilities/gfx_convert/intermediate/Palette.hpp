#ifndef Palette_hpp
#define Palette_hpp

#include <stdint.h>
#include <vector>

class Palette {

public:
    Palette();
    Palette(std::vector<uint32_t> rgba32_palette);
    Palette(const std::vector<uint8_t> &rgba24_palette);

    std::vector<uint32_t> rgba32_palette;

    std::vector<uint16_t> ics_palette() const;
};

#endif /* Palette_hpp */
