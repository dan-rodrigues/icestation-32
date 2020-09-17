// main.c
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#include <stdint.h>
#include <stdbool.h>

#include "audio.h"

#include "vdp.h"
#include "font.h"
#include "vdp_print.h"
#include "gamepad.h"

#include "snare.h"
#include "kick.h"
#include "cymbal.h"

const uint16_t MAP_VRAM_BASE = 0x4000;
const uint16_t TILE_VRAM_BASE = 0x0000;

void print_channel_states(void);

int main() {
    // Configure video (to display channel status)

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

    // Configure channel context

    static const int16_t *sample_pointers[] = {snare, kick, cymbal};
    const size_t sample_lengths[] = {snare_length, kick_length, cymbal_length};

    const int8_t volume = 0x0c;

    for (uint32_t i = 0; i < sizeof(sample_pointers) / sizeof(int16_t*); i++) {
        volatile AudioChannel *ch = &AUDIO->channels[i];
        audio_set_aligned_addresses(ch, sample_pointers[i], sample_lengths[i]);
        ch->pitch = 0x1000;
        ch->flags = 0;
        ch->volumes.left = volume;
        ch->volumes.right = volume;
    }

    uint16_t p1_pad_edge, p1_pad;

    // Play channels according to user input

    while (true) {
        pad_read(&p1_pad, NULL, &p1_pad_edge, NULL);

        if (!AUDIO_STATUS_BUSY) {
            uint16_t start_mask = 0;
            start_mask |= (p1_pad_edge & GP_B) ? 0x01 : 0;
            start_mask |= (p1_pad_edge & GP_LEFT) ? 0x02 : 0;
            start_mask |= (p1_pad_edge & GP_RIGHT) ? 0x04 : 0;
            AUDIO_GB_PLAY = start_mask;
        }

        vdp_wait_frame_ended();
        print_channel_states();
    }
}

void print_channel_states() {
    const uint8_t base_x = 2;
    const uint8_t base_y = 2;

    static const char *sample_labels[] = {"Snare ", "Kick  ", "Cymbal"};

    vp_printf(base_x, base_y, 0, SCROLL0, MAP_VRAM_BASE, "Channel   Sample    Status");
    vp_printf(base_x, base_y + 1, 0, SCROLL0, MAP_VRAM_BASE, "--------- --------- ---------");

    for (uint32_t i = 0; i < 3; i++) {
        uint8_t y = base_y + i * 2 + 2;
        char *status = (AUDIO_STATUS_PLAYING & (1 << i)) ? "Playing" : "Stopped";

        vp_printf(base_x, y, 0, SCROLL0, MAP_VRAM_BASE,
                  "%d         %s    %s",
                  i, sample_labels[i], status);
    }

    vp_printf(base_x, base_y + 10, 0, SCROLL0, MAP_VRAM_BASE, "Press buttons to play");
}
