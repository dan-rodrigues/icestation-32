#include "Tiles.hpp"

#include <iostream>

Tiles::Tiles(std::vector<uint8_t> image, uint16_t width, uint16_t height) {
    this->image = image;
    this->width = width;
    this->height = height;
}

// 4bpp conversion
std::vector<uint32_t> Tiles::ics_tiles() {
    std::vector<uint32_t> tiles;

    const uint8_t tiles_x_total = width / 8;
    const uint8_t tiles_y_total = height / 8;

    // convert from the bitmap format to the 8x8 4bpp format
    for (uint8_t tile_y = 0; tile_y < tiles_y_total; tile_y++) {
        for (uint8_t tile_x = 0; tile_x < tiles_x_total; tile_x++) {
            // 8x8 conversion
            for (uint8_t pixel_y = 0; pixel_y < 8; pixel_y++) {
                // write adjacent pixels at a time
                uint8_t low_pixel = 0;
                uint32_t pixel_row = 0;

                for (uint8_t pixel_x = 0; pixel_x < 8; pixel_x++) {
                    uint16_t x = tile_x * 8 + pixel_x;
                    uint16_t y = tile_y * 8 + pixel_y;
                    uint16_t base_index = y * width + x;

                    uint8_t pixel = image[base_index];
                    if (pixel > 0x0f) {
                        std::cerr << "Pixel out of range for 4bpp conversion: " << std::hex << pixel << std::endl;
                        pixel = 0;
                    }

                    if (pixel_x % 2) {
                        pixel_row <<= 8;
                        pixel_row |= (pixel << 4 | low_pixel);
                    } else {
                        low_pixel = pixel;
                    }
                }

                tiles.push_back(pixel_row);
            }
        }
    }

    return tiles;
}

// packed 4bpp conversion

std::vector<uint8_t> Tiles::packed_4bpp_tiles() {
    std::vector<uint8_t> tiles;
    uint8_t pixel_pair = 0;

    for (size_t i = 0; i < this->image.size(); i++) {
        uint8_t pixel = this->image[i];

        if (i % 2) {
            tiles.push_back(pixel << 4 | pixel_pair);
        } else {
            pixel_pair = pixel;
        }
    }

    return tiles;
}

// SNES format -> ics conversion

Tiles::Tiles(std::vector<uint8_t> snes_tiles) {
    std::vector<uint8_t> tiles;

    const auto snes_tile_size = 32;

    auto size = tiles.size();
    if (size % snes_tile_size) {
        std::cerr << "Warning: expected size of SNES tiles to be a multiple of 32" << std::endl;
        size &= ~(snes_tile_size - 1);
    }

    const auto tile_count = size / snes_tile_size;

    for (auto tile = size / snes_tile_size; tile < tile_count; tile++) {
        for (auto row = 0; row < 8; row++) {
            auto index = tile * snes_tile_size + row * 2;

            auto bp0 = snes_tiles[index];
            auto bp1 = snes_tiles[index + 1];
            auto bp2 = snes_tiles[index + 16];
            auto bp3 = snes_tiles[index + 17];

            uint32_t converted_row = 0;
            for (auto pixel = 0; pixel < 8; pixel++) {
                converted_row <<= 4;
                uint8_t converted_pixel = 0;

                converted_pixel |= (bp3 & 0x80) >> 4;
                converted_pixel |= (bp2 & 0x80) >> 5;
                converted_pixel |= (bp1 & 0x80) >> 6;
                converted_pixel |= (bp0 & 0x80) >> 7;

                bp3 <<= 1;
                bp2 <<= 1;
                bp1 <<= 1;
                bp0 <<= 1;

                converted_row |= converted_pixel;
            }
        }
    }

    this->image = tiles;
}

// TODO: 256 color (for affine layer)

/*
 std::vector<uint16_t> SNES::convertedTiles(uint16_t tileBase, uint16_t charCount) {
     auto convertedTiles = std::vector<uint16_t>();

     for(int i = 0; i < charCount; i++) {
         // read whole row of snes graphics
         for(int y = 0; y < 8; y++) {
             uint32_t convertedrow = 0;
             uint8_t p0 = vram[tileBase + i * 32 + y * 2];
             uint8_t p1 = vram[tileBase + i * 32 + y * 2 + 1];
             uint8_t p2 = vram[tileBase + i * 32 + y * 2 + 16];
             uint8_t p3 = vram[tileBase + i * 32 + y * 2 + 17];
             for(int pixel = 0; pixel < 8; pixel++) {
                 // no harm done if this is done at the start
                 convertedrow <<= 4; // make room for next pixel
                 // 4bit chunky pixel
                 uint8_t chunky = (p3 &0x80) >> 4;
                 chunky |= (p2&0x80) >> 5;
                 chunky |= (p1&0x80) >> 6;
                 chunky |= (p0&0x80) >> 7;
                 p3 <<= 1;
                 p2 <<= 1;
                 p1 <<= 1;
                 p0 <<= 1;

                 convertedrow |= chunky;
             }

             convertedTiles.push_back(convertedrow &0xffff);
             convertedTiles.push_back(convertedrow >> 16);
         }
     }

     return convertedTiles;
 }
 */
