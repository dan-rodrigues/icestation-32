#include "vdp_print.h"

static void seek(uint8_t x, uint8_t y, VDPLayer layer, uint16_t vram_base) {
    bool second_page = (x % 128) >= 64;
    x %= 64;

    uint16_t address = y * 64 + x;
    address += (second_page ? 0x1000 : 0);
    address *= 2;

    address += (vdp_layer_is_odd(layer) ? 1 : 0);
    vdp_seek_vram(vram_base + address);
}

void vp_print(const char *string, uint8_t x, uint8_t y, uint8_t palette, VDPLayer layer, uint16_t vram_base) {
    vdp_set_vram_increment(2);
    seek(x, y, layer, vram_base);

    while (*string) {
        uint16_t map = *string++ & 0xff;
        map |= palette << SCROLL_MAP_PAL_SHIFT;

        vdp_write_vram(map);
        x++;

        if (x == 64) {
            seek(x, y, layer, vram_base);
        }
    }

    vdp_set_vram_increment(1);
}

uint8_t vp_center_string_x(const char *string) {
    uint8_t length = 0;
    while (*string++) {
        length++;
    }

    return SCREEN_ACTIVE_WIDTH / 8 / 2 - length / 2;
}
