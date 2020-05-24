#ifndef Tiles_hpp
#define Tiles_hpp

#include <stdint.h>
#include <vector>

#include "lodepng.h"

class Tiles {

public:
    Tiles(std::vector<uint8_t> image, uint16_t width, uint16_t height);
    Tiles(std::vector<uint8_t> snes_tiles);

    std::vector<uint32_t> ics_tiles();
    std::vector<uint8_t> packed_4bpp_tiles();

    std::vector<uint8_t> image;
    uint16_t width;
    uint16_t height;
};

#endif /* Tiles_hpp */
