#include <iostream>
#include <optional>

#include "Image.hpp"
#include "ImageMetrics.h"

#include "lodepng.h"
#include "lodepng_util.h"

Image::Image() : bpp(0) {}

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
    this->tiles = Tiles(tile_data);

    // Was a palette provided?..
    if (!palette_data.empty()) {
        this->palette = Palette(palette_data);
    } else {
        // ...if not, generate a simple monochrome one
        std::vector<uint8_t> mono_palette;
        for (auto i = 0; i < 16 * 16; i++) {
            uint8_t component = i << 4;
            mono_palette.push_back(component);
            mono_palette.push_back(component);
            mono_palette.push_back(component);
        }

        this->palette = Palette(mono_palette);
    }
}

