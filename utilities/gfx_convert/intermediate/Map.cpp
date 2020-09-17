#include "Map.hpp"

std::vector<uint16_t> Map::ics_map() {
    const auto dimension = 64;
    size_t total_tiles = dimension * dimension;
    total_tiles = std::min(vram.size() / sizeof(uint16_t), total_tiles);

    std::vector<uint16_t> converted_map;

    for(uint16_t i = 0; i < total_tiles; i++) {
        // Map the 64x64 space to a snes address
        uint16_t offset = 0;
        uint16_t snesx = i & 0x1f;
        uint16_t snesy = (i / 64) & 0x1f;
        uint16_t snes_map_base = (snesx + snesy * 0x20) * 2;

        if (i & 0x20) {
            offset += 0x800;
        }
        if (i >= 64 * 32) {
            offset += 0x1000;
        }

        uint16_t snes_map = vram[offset + snes_map_base];
        snes_map |= vram[offset + snes_map_base + 1] << 8;

        uint16_t new_map = (snes_map & 0x01ff);
        uint16_t y_flip = snes_map & 0x8000;
        new_map |= y_flip ? 1 << 10 : 0;

        uint16_t x_flip = snes_map & 0x4000;
        new_map |= x_flip ? 1 << 9 : 0;

        uint16_t palette = (snes_map & 0x1c00) >> 10;
        new_map |= palette << 12;

        converted_map.push_back(new_map);
    }

    return converted_map;
}

