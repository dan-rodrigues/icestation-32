// TODO: header

#include "Palette.hpp"

Palette::Palette(lodepng::State state) {
    // maybe remove the lode specific stuff here
    // extract rgba32 colors first
    uint32_t *palette = reinterpret_cast<uint32_t *>(state.info_png.color.palette);
    size_t palette_size = state.info_png.color.palettesize;
    this->colors = std::vector<uint32_t>(palette, palette + palette_size);
}

std::vector<uint16_t> Palette::ics_palette() {
    std::vector<uint16_t> ics_palette;

    // TODO: rounding up of colors if needed
    for (auto it = begin(colors); it != end(colors); ++it) {
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
