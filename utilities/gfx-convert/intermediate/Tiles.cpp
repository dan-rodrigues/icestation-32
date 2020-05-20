// TODO: headers

#include "Tiles.hpp"

#include <iostream>

Tiles::Tiles(std::vector<uint8_t> image, uint16_t width, uint16_t height) {
    this->image = image;
    this->width = width;
    this->height = height;
}

// 4bpp
// FIXME this doesn't take into accoutn the 256px stride between tiles below
// but this might be a requirement of the input instead
std::vector<uint8_t> Tiles::ics_tiles() { 
    std::vector<uint8_t> tiles;

    const uint8_t tiles_x_total = width / 8;
    const uint8_t tiles_y_total = height / 8;

    // convert from the bitmap format to the 8x8 4bpp format
    for (uint8_t tile_y = 0; tile_y < tiles_y_total; tile_y++) {
        for (uint8_t tile_x = 0; tile_x < tiles_x_total; tile_x++) {
            // 8x8 conversion
            for (uint8_t pixel_y = 0; pixel_y < 8; pixel_y++) {
                // write 2 adjacent pixels at a time
                uint8_t high_pixel = 0;

                for (uint8_t pixel_x = 0; pixel_x < 8; pixel_x++) {
                    uint16_t x = tile_x * 8 + (~pixel_x & 7);
                    uint16_t y = tile_y * 8 + pixel_y;
                    uint16_t base_index = y * width + x;

                    uint8_t pixel = image[base_index];
                    if (pixel > 0x0f) {
                        std::cerr << "pixel out of range for 4bpp conversion: " << std::hex << pixel << std::endl;
                        pixel = 0;
                    }

                    if (pixel_x % 2) {
                        tiles.push_back(pixel | high_pixel << 4);
                    } else {
                        high_pixel = pixel;
                    }
                }
            }
        }
    }


    return tiles;
}

// TODO: 256 color (for affine layer)

