// main.c
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#include <stdint.h>
#include <stdbool.h>

#include "ym2151.h"

#include "vdp.h"
#include "font.h"
#include "vdp_print.h"
#include "gamepad.h"

#include "track.h"

static const uint16_t MAP_VRAM_BASE = 0x4000;
static const uint16_t TILE_VRAM_BASE = 0x0000;

static void print_status(const char *fmt, ...);
static void print_loop_count(void);

static uint32_t ym_prescaler(uint32_t ym_clock);

static void vgm_player_sanity_check(void);
static void vgm_player_init(void);
static uint32_t vgm_player_update(void);

static void delay(uint32_t delay);

static size_t vgm_index;
static size_t vgm_loop_offset;
static uint32_t vgm_loop_count;

int main() {
    vdp_enable_layers(SCROLL0);
    vdp_set_wide_map_layers(SCROLL0);
    vdp_set_alpha_over_layers(0);

    vdp_set_vram_increment(1);

    vdp_set_layer_scroll(0, 0, 0);

    vdp_seek_vram(0x0000);
    vdp_fill_vram(0x8000, ' ');

    vdp_set_layer_tile_base(0, TILE_VRAM_BASE);
    upload_font(TILE_VRAM_BASE);

    const uint16_t bg_color = 0xf033;
    const uint16_t fg_color = 0xffff;

    vdp_set_single_palette_color(0, bg_color);
    vdp_set_single_palette_color(1, fg_color);

    vdp_set_layer_map_base(0, MAP_VRAM_BASE);
    vdp_seek_vram(MAP_VRAM_BASE);

    vp_print_init();

    // Prepare YM2151 playback

    const uint8_t title_x = 44;
    const uint8_t title_y = 8;
    const char * const title = "--- YM2151 player ---";
    vp_printf(title_x, title_y, 0, SCROLL0, MAP_VRAM_BASE, title);

    vgm_player_sanity_check();
    vgm_player_init();

    print_status("Playing...");

    // Start YM2151 playback

    while (true) {
        uint32_t delay_ticks = vgm_player_update();
        delay(delay_ticks);
    }
}

static void vgm_player_sanity_check() {
    static const char * const identity_string = "Vgm ";

    bool identity_matches = true;

    for (size_t i = 0; i < 4; i++) {
        if (track[i] != identity_string[i]) {
            identity_matches = false;
            break;
        }
    }

    if (!identity_matches) {
        print_status("Error: VGM identify string not found.");
        vp_printf(27, 30, 0, SCROLL0, MAP_VRAM_BASE,
                  "Remember to unzip any .vgz files and include them before building");
        while(true) {}
    }
}

// This delay function is used in absence of IRQ or the timer instructions
// If I end up redoing this properly, there will be a hardware timer instead of this
// This is fine for a demo

__attribute__((noinline))
static void delay(uint32_t delay) {
    if (!delay) {
        return;
    }

    // This constant effectively controls the tempo
    // This assumes PicoRV32 is used as configured in this branch
    // (382.65 CPU cycles per sample)
    const uint32_t inner_loop_iterations = 35;

    uint32_t inner_loop_counter;

    __asm __volatile__
    (
     "loop_outer:\n"

     "li %1, %2\n"

     "loop_inner:\n"
     "addi %1, %1, -1\n"
     "bnez %1, loop_inner\n"

     "addi %0, %0, -1\n"
     "bnez %0, loop_outer\n"
     : "+r" (delay), "=r" (inner_loop_counter)
     : "i" (inner_loop_iterations)
     :
    );
}

static uint32_t ym_prescaler(uint32_t ym_clock) {
    const uint32_t system_clock = 33750000 / 2;

    return ((uint64_t)ym_clock << 32) / system_clock;
}

static void print_status(const char *fmt, ...) {
    const uint8_t status_x = 44;
    const uint8_t status_y = 11;

    va_list args;
    va_start(args, fmt);
    vp_printf_list(status_x, status_y, 0, SCROLL0, MAP_VRAM_BASE, fmt, args);
    va_end(args);
}

static void vgm_player_init() {
    const uint8_t stats_x = 20;
    const uint8_t stats_y = 18;

    // VGM start offset

    const size_t relative_offset_index = 0x34;

    uint32_t relative_offset = track[relative_offset_index + 0];
    relative_offset |= track[relative_offset_index + 1] << 8;
    relative_offset |= track[relative_offset_index + 2] << 16;
    relative_offset |= track[relative_offset_index + 3] << 24;

    vgm_index = relative_offset ? relative_offset_index + relative_offset : 0x40;

    // VGM loop offset (optional

    const size_t loop_offset_index = 0x1c;

    uint32_t loop_offset = track[loop_offset_index + 0];
    loop_offset |= track[loop_offset_index + 1] << 8;
    loop_offset |= track[loop_offset_index + 2] << 16;
    loop_offset |= track[loop_offset_index + 3] << 24;

    vgm_loop_offset = loop_offset ? loop_offset_index + loop_offset : 0;

    // YM2151 clock is different depending on the hardware

    const size_t ym_clock_offset = 0x30;

    uint32_t ym_clock = track[ym_clock_offset + 0];
    ym_clock |= track[ym_clock_offset + 1] << 8;
    ym_clock |= track[ym_clock_offset + 2] << 16;

    uint32_t computed_prescaler = ym_prescaler(ym_clock);
    YM2151_PRESCALER = computed_prescaler;

    // Print some stats

    vp_printf(stats_x, stats_y, 0, SCROLL0, MAP_VRAM_BASE,
              "Start offset: 0x%08X", vgm_index);
    vp_printf(stats_x, stats_y + 2, 0, SCROLL0, MAP_VRAM_BASE,
              "Loop offset:  0x%08X", vgm_loop_offset);

    vp_printf(stats_x, stats_y + 5, 0, SCROLL0, MAP_VRAM_BASE,
              "YM2151 clock: %dHz", ym_clock);
    vp_printf(stats_x, stats_y + 7, 0, SCROLL0, MAP_VRAM_BASE,
              "YM2151 computed prescaler: %d", computed_prescaler);

    print_loop_count();
}

static uint32_t vgm_player_update() {
    while (true) {
        uint8_t cmd = track[vgm_index++];

        if ((cmd & 0xf0) == 0x70) {
            // 0x7X
            // Wait X samples
            return cmd & 0x0f;
        }

        switch (cmd) {
            case 0x54: {
                // 0x54 XX YY
                // Write reg[XX] = YY
                const uint8_t YM2151_BUSY_FLAG = 0x80;
                while (YM2151_STATUS & YM2151_BUSY_FLAG) {}

                uint8_t reg = track[vgm_index++];
                YM2151_REG_ADDRESS = reg;
                uint8_t data = track[vgm_index++];
                YM2151_REG_DATA = data;
            } break;
            case 0x61: {
                // 0x61 XX XX
                // Wait XXXX samples
                uint16_t delay = track[vgm_index++];
                delay |= track[vgm_index++] << 8;
                return delay;
            }
            case 0x62:
                // 60hz frame wait
                return 735;
            case 0x63:
                // 50hz frame wait
                return 882;
            case 0x66: {
                // End of stream
                vgm_loop_count++;

                if (vgm_loop_offset) {
                    vgm_index = vgm_loop_offset;
                } else {
                    // If there's no loop, just restart the player
                    vgm_player_init();
                }

                print_loop_count();

                return 0;
            }
            default:
                print_status("Unsupported command: %X", cmd);
                while(true) {}
        }
    }
}

static void print_loop_count() {
    const uint8_t loop_x = 20;
    const uint8_t loop_y = 28;

    vp_printf(loop_x, loop_y, 0, SCROLL0, MAP_VRAM_BASE,
              "Loop count: %d", vgm_loop_count);
}
