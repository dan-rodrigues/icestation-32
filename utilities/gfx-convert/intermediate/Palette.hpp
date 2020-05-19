// TODO: header

#ifndef Palette_hpp
#define Palette_hpp

#include <vector>

#include "lodepng.h"

class Palette {

public:
    Palette(lodepng::State state);

    std::vector<uint32_t> colors;

    std::vector<uint16_t> ics_palette();
};

#endif /* Palette_hpp */
