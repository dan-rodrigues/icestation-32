#include "Tiles.hpp"
#include "ImageMetrics.h"

#include <iostream>

Tiles::Tiles() : width(0), height(0) {}

Tiles::Tiles(std::vector<uint8_t> bitmap, uint16_t width, uint16_t height) {
    this->bitmap = bitmap;
    this->width = width;
    this->height = height;
}

// 4bpp conversion
std::vector<uint32_t> Tiles::ics_tiles() const {
    std::vector<uint32_t> tiles;

    const uint8_t tiles_x_total = this->width / 8;
    const uint8_t tiles_y_total = this->height / 8;

    // convert from the bitmap format to the 8x8 4bpp format
    for (uint8_t tile_y = 0; tile_y < tiles_y_total; tile_y++) {
        for (uint8_t tile_x = 0; tile_x < tiles_x_total; tile_x++) {
            // 8x8 conversion
            for (uint8_t pixel_y = 0; pixel_y < 8; pixel_y++) {
                // write adjacent pixels at a time
                uint8_t high_pixel = 0;
                uint32_t pixel_row = 0;

                for (uint8_t pixel_x = 0; pixel_x < 8; pixel_x++) {
                    uint16_t x = tile_x * 8 + pixel_x;
                    uint16_t y = tile_y * 8 + pixel_y;
                    uint16_t base_index = y * width + x;

                    uint8_t pixel = bitmap[base_index];
                    if (pixel > 0x0f) {
                        std::cerr << "Pixel out of range for 4bpp conversion: " << std::hex << pixel << std::endl;
                        pixel = 0;
                    }

                    if (pixel_x % 2) {
                        pixel_row <<= 8;
                        pixel_row |= (pixel | high_pixel << 4);
                    } else {
                        high_pixel = pixel;
                    }
                }

                tiles.push_back(pixel_row);
            }
        }
    }

    return tiles;
}

// packed 4bpp conversion

std::vector<uint8_t> Tiles::packed_4bpp_tiles() const {
    std::vector<uint8_t> tiles;
    uint8_t high_pixel = 0;

    for (auto i = 0; i < this->bitmap.size(); i++) {
        uint8_t pixel = this->bitmap[i];

        if (i % 2) {
            tiles.push_back(pixel | high_pixel << 4);
        } else {
            high_pixel = pixel;
        }
    }

    return tiles;
}

// SNES format

Tiles::Tiles(std::vector<uint8_t> snes_tiles) {
    std::vector<uint8_t> bitmap;
    bitmap.resize(snes_tiles.size() * 2);

    const auto tile_size = ImageMetrics::SNES::TILE_SIZE;

    auto size = snes_tiles.size();
    if (size % tile_size) {
        std::cerr << "Warning: expected size of SNES tiles to be a multiple of 32" << std::endl;
        size &= ~(tile_size - 1);
    }

    const auto tile_count = size / tile_size;

    for (auto tile = 0; tile < tile_count; tile++) {
        for (auto row = 0; row < 8; row++) {
            auto read_index = tile * tile_size + row * 2;

            auto bp0 = snes_tiles[read_index];
            auto bp1 = snes_tiles[read_index + 1];
            auto bp2 = snes_tiles[read_index + 16];
            auto bp3 = snes_tiles[read_index + 17];

            for (auto pixel = 0; pixel < 8; pixel++) {
                uint8_t converted_pixel = 0;

                converted_pixel |= (bp3 & 0x80) >> 4;
                converted_pixel |= (bp2 & 0x80) >> 5;
                converted_pixel |= (bp1 & 0x80) >> 6;
                converted_pixel |= (bp0 & 0x80) >> 7;

                auto x = tile % 16 * 8 + pixel;
                auto y = tile / 16 * 8 + row;
                auto write_index = y * 128 + x;

                bitmap[write_index] = converted_pixel;

                bp3 <<= 1;
                bp2 <<= 1;
                bp1 <<= 1;
                bp0 <<= 1;
            }
        }
    }

    this->bitmap = bitmap;
    this->width = ImageMetrics::SNES::TILE_ROW_STRIDE;
    this->height = bitmap.size() / this->width;
}


// TODO: 256 color (for affine layer)
