#include <iostream>
#include <optional>

#include "Image.hpp"
#include "ImageMetrics.h"

#include "lodepng.h"
#include "lodepng_util.h"

Image::Image() : bpp(0), width(0), height(0) {}

Image::Image(std::vector<uint8_t> tile_data, std::vector<uint8_t> palette_data, InputFormat format) {
    switch (format) {
        case PNG:
            this->init_from_png(tile_data);
            break;
        case SNES:
            this->init_from_snes(tile_data, palette_data);
            break;
        default:
            throw std::invalid_argument("Input format not handled: " + std::to_string(format));
    }

    // 16 colors only for now
    this->bpp = 4;
}

void Image::init_from_png(std::vector<uint8_t> data) {
    uint32_t width, height;
    std::vector<uint8_t> png_decoded;
    lodepng::State lode_state;

    lode_state.decoder.color_convert = 0;

    auto error = lodepng::decode(png_decoded, width, height, lode_state, data);
    if (error) {
        throw std::invalid_argument("Failed to decode png: " + std::string(lodepng_error_text(error)));
    }

    if (lode_state.info_png.color.colortype == LCT_PALETTE) {
        std::cout << "Found paletted image" << std::endl;
        std::cout << "Palette size: " << lode_state.info_raw.palettesize << std::endl;
    } else {
        throw std::invalid_argument("only color-indexed PNG files not supported for now");
    }

    this->width = width;
    this->height = height;

    std::vector<uint8_t> indexed_image;
    for (auto y = 0; y < height; y++) {
        for (auto x = 0; x < width; x++) {
            auto pixel_index = y * width + (x ^ 0x01);
            auto palette_index = lodepng::getPaletteValue(&png_decoded[0], pixel_index, lode_state.info_raw.bitdepth);
            indexed_image.push_back(palette_index);
        }
    }

    this->tiles = Tiles(indexed_image, width, height);

    uint32_t *png_palette = reinterpret_cast<uint32_t *>(lode_state.info_png.color.palette);
    size_t palette_size = lode_state.info_png.color.palettesize;
    std::vector<uint32_t> rgba32_palette(png_palette, png_palette + palette_size);

    this->palette = Palette(rgba32_palette);
}

void Image::init_from_snes(std::vector<uint8_t> tile_data, std::vector<uint8_t> palette_data) {
    this->width = ImageMetrics::SNES::TILE_ROW_STRIDE;
    this->height = tile_data.size() / (ImageMetrics::SNES::TILE_ROW_STRIDE / 2);

    this->tiles = Tiles(tile_data);

    std::vector<uint32_t> rgba32_palette;

    // was a palette provided?
    if (!palette_data.empty()) {
        auto palette_size = palette_data.size();
        if (palette_size % 3) {
            std::cerr << "Warning: expected palette to byte 3 bytes per color" << std::endl;
            palette_size -= palette_size % 3;
        }

        // (eventually 256 color support needed)
        const auto palette_size_4bpp = 16;
        const auto rgb24_size = 3;

        for (auto i = 0; i < palette_size_4bpp; i++) {
            size_t index = i * rgb24_size;
            uint8_t r = palette_data[index];
            uint8_t g = palette_data[index + 1];
            uint8_t b = palette_data[index + 2];
            uint32_t color = 0xff << 24 | r | g << 8 | b << 16;

            rgba32_palette.push_back(color);
        }
    } else {
        // ...if not, generate a simple monochrome one
        for (auto i = 0; i < 16 * 16; i++) {
            uint8_t component = i << 4;
            uint32_t color = component | component << 8 | component << 16;
            color |= 0xff << 24;
            rgba32_palette.push_back(color);
        }
    }

    this->palette = Palette(rgba32_palette);
}

