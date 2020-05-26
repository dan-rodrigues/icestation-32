#include "Palette.hpp"

Palette::Palette() {}

std::vector<uint16_t> Palette::ics_palette() {
    std::vector<uint16_t> ics_palette;

    auto round = [] (uint8_t component) {
        return (component - 8) / 0x10;
    };

    for (auto it = begin(rgba32_palette); it != end(rgba32_palette); ++it) {
        uint32_t color = *it;
        uint8_t a = round(color >> 24 & 0xff);
        uint8_t b = round(color >> 16 & 0xff);
        uint8_t g = round(color >> 8 & 0xff);
        uint8_t r = round(color & 0xff);

        uint16_t ics_color = a << 12 | r << 8 | g << 4 | b;
        ics_palette.push_back(ics_color);
    }

    return ics_palette;
}

Palette::Palette(std::vector<uint32_t> rgba32_palette) { 
    this->rgba32_palette = rgba32_palette;
}
