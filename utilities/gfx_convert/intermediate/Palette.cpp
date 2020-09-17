#include "Palette.hpp"

#include <iostream>

Palette::Palette() {}

Palette::Palette(std::vector<uint32_t> rgba32_palette) {
    this->rgba32_palette = rgba32_palette;
}

Palette::Palette(const std::vector<uint8_t> &rgba24_palette) {
    auto palette_size = rgba24_palette.size();
    if (palette_size % 3) {
        std::cerr << "Warning: expected palette to byte 3 bytes per color" << std::endl;
        palette_size -= palette_size % 3;
    }

    // (eventually 256 color support needed)
    const auto palette_size_4bpp = 16;
    const auto rgb24_size = 3;

    for (auto i = 0; i < palette_size_4bpp; i++) {
        size_t index = i * rgb24_size;
        uint8_t r = rgba24_palette[index];
        uint8_t g = rgba24_palette[index + 1];
        uint8_t b = rgba24_palette[index + 2];
        uint32_t color = 0xff << 24 | r | g << 8 | b << 16;

        rgba32_palette.push_back(color);
    }
}

std::vector<uint16_t> Palette::ics_palette() const {
    std::vector<uint16_t> ics_palette;

    auto round = [] (uint8_t component) {
        return (component - 8) / 0x10;
    };

    for (auto color : this->rgba32_palette) {
        uint8_t a = round(color >> 24 & 0xff);
        uint8_t b = round(color >> 16 & 0xff);
        uint8_t g = round(color >> 8 & 0xff);
        uint8_t r = round(color & 0xff);

        uint16_t ics_color = a << 12 | r << 8 | g << 4 | b;
        ics_palette.push_back(ics_color);
    }

    return ics_palette;
}
