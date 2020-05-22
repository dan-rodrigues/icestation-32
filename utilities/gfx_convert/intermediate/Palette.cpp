#include "Palette.hpp"

std::vector<uint16_t> Palette::ics_palette() {
    std::vector<uint16_t> ics_palette;

    // TODO: rounding up of colors if needed + clipping
    for (auto it = begin(rgba32_palette); it != end(rgba32_palette); ++it) {
        uint32_t color = *it;
        uint8_t a = (color >> 24 & 0xff) >> 4;
        uint8_t b = (color >> 16 & 0xff) >> 4;
        uint8_t g = (color >> 8 & 0xff) >> 4;
        uint8_t r = (color & 0xff) >> 4;

        uint16_t ics_color = a << 12 | r << 8 | g << 4 | b;
        ics_palette.push_back(ics_color);
    }

    return ics_palette;
}

Palette::Palette(std::vector<uint32_t> rgba32_palette) { 
    this->rgba32_palette = rgba32_palette;
}

