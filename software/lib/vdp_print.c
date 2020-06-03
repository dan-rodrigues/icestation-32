#include "vdp_print.h"

static void print_seek(uint8_t x, uint8_t y, VDPLayer layer, uint16_t vram_base) {
    bool second_page = (x % 128) >= 64;
    x %= 64;

    uint16_t address = y * 64 + x;
    address += (second_page ? 0x1000 : 0);
    address *= 2;

    address += (vdp_layer_is_odd(layer) ? 1 : 0);
    vdp_seek_vram(vram_base + address);
}

void print(const char *string, uint8_t x, uint8_t y, uint8_t palette, VDPLayer layer, uint16_t vram_base) {
    uint8_t page_chars_remaining = 64 - (x % 64);
    bool needs_seek = true;

    while (*string++) {
        // this is needed after each character to handle the map page crossing
        // the number of characters to print before a page crossing could optimise this

        if (needs_seek) {
            print_seek(x, y, layer, vram_base);
            page_chars_remaining = 64;
            needs_seek = false;
        }

        uint16_t map = *string & 0xff;
        map |= palette << SCROLL_MAP_PAL_SHIFT;

        vdp_write_vram(map);

        x++;
        
        page_chars_remaining--;
        needs_seek = !page_chars_remaining;
    }
}
