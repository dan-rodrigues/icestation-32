#ifndef Image_hpp
#define Image_hpp

#include <stdint.h>
#include <vector>

#include "Tiles.hpp"
#include "Palette.hpp"

enum InputFormat { PNG, SNES };

class Image {

public:
    Image();
    Image(std::vector<uint8_t> tile_data, std::vector<uint8_t> palette_data, InputFormat format);

    uint8_t bpp;

    uint16_t width;
    uint16_t height;

    Tiles tiles;
    Palette palette;

private:
    void init_from_png(std::vector<uint8_t> data);
    void init_from_snes(std::vector<uint8_t> tile_data, std::vector<uint8_t> palette_data);
};

#endif /* Image_hpp */
