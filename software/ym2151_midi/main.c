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
#include "opm.h"

static const uint16_t MAP_VRAM_BASE = 0x4000;
static const uint16_t TILE_VRAM_BASE = 0x0000;

static void print_status(const char *fmt, ...);

static uint32_t ym_prescaler(uint32_t ym_clock);

// 2151 voices:

typedef struct {
    uint8_t ar, d1r, d2r, rr, d1l, tl, ks, mul, dt1, dt2, ame;
} OPMOperator;

typedef struct {
    // LFO:
    uint8_t lfrq, amd, pmd, wf, nfrq;
    // CH:
    uint8_t pan, fl, con, ams, pms, slot_mask, ne;
    // Operators (M1, C1, M2, C2):
    OPMOperator operators[4];
} OPMVoice;

static void ym_init(void);

static void ym_write(uint8_t reg, uint8_t data);
static void ym_configure_voice(uint8_t ch, const OPMVoice *voice);
static void ym_load_opm_bin(const uint8_t *opm_bin, OPMVoice *voice);

static void ym_play(uint8_t ch, uint8_t packed_note);
static void ym_key_off(uint8_t ch);

static uint8_t ym_note_from_midi(uint8_t midi_note);
static uint8_t ym_pack_note(uint8_t octave, uint8_t note);

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

    const uint8_t title_x = 44;
    const uint8_t title_y = 8;
    const char * const title = "--- YM2151 MIDI ---";
    vp_printf(title_x, title_y, 0, SCROLL0, MAP_VRAM_BASE, title);

    print_status("Awaiting input...");

    ym_init();

    uint16_t pad = 0, pad_edge = 0, pad_negedge = 0;

    ym_play(0, ym_note_from_midi(0x3c));

    while (true) {
        pad_negedge = pad;
        pad_read(&pad, NULL, &pad_edge, NULL);
        pad_negedge &= ~pad;

        PadInputDecoded pad_decoded = {}, pad_decoded_negedge = {};
        pad_decode_input(pad_edge, &pad_decoded);
        pad_decode_input(pad_negedge, &pad_decoded_negedge);

        // ...
        
        // Key on with fixed notes

        if (pad_decoded.b) {
            ym_play(0, ym_pack_note(4, 14));
        }
        if (pad_decoded.a) {
            ym_play(1, ym_pack_note(5, 4));
        }
        if (pad_decoded.x) {
            ym_play(2, ym_pack_note(5, 8));
        }
        if (pad_decoded.y) {
            ym_play(3, ym_pack_note(5, 14));
        }
        if (pad_decoded.l) {
            ym_play(4, ym_pack_note(5, 4));
        }
        if (pad_decoded.r) {
            ym_play(5, ym_pack_note(5, 7));
        }

        // Key off on release

        if (pad_decoded_negedge.b) {
            ym_key_off(0);
        }
        if (pad_decoded_negedge.a) {
            ym_key_off(1);
        }
        if (pad_decoded_negedge.x) {
            ym_key_off(2);
        }

        // Volume control

        if (pad_decoded.up) {
            YM2151_EXT_VOLUME = 0x01;
        } else if (pad_decoded.down) {
            YM2151_EXT_VOLUME = 0x00;
        }

        vdp_wait_frame_ended();
    }
}

static uint8_t ym_pack_note(uint8_t octave, uint8_t note) {
    return octave << 4 | note;
}

static uint8_t ym_note_from_midi(uint8_t midi_note) {
    uint8_t octave = midi_note / 12;
    uint8_t note = midi_note % 12;

    static const uint8_t ym_note_map[] = {
        // C, C# ... A#, B
        14, 0, 1, 2, 4, 5, 6, 8, 9, 10, 12, 13
    };

    return octave << 4 | ym_note_map[note];
}

static void ym_play(uint8_t ch, uint8_t packed_note) {
    OPMVoice voice;
    ym_load_opm_bin(opm, &voice);
    ym_configure_voice(ch, &voice);

    // Key off first:

    ym_write(0x08, ch);

    ym_write(0x28 + ch, packed_note);
    ym_write(0x30 + ch, 0);

    // Key on:

    // slot_mask is preshifted << 3 in OPM format
    uint8_t kon_byte = voice.slot_mask | ch;
    ym_write(0x08, kon_byte);
}

static void ym_key_off(uint8_t ch) {
    ym_write(0x08, ch);
}

static void ym_init() {
    const uint32_t ym_clock = 3580000;

    uint32_t computed_prescaler = ym_prescaler(ym_clock);
    YM2151_PRESCALER = computed_prescaler;
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

// New stuff for MIDI support

static void ym_write(uint8_t reg, uint8_t data) {
    const uint8_t YM2151_BUSY_FLAG = 0x80;
    while (YM2151_STATUS & YM2151_BUSY_FLAG) {}

    YM2151_REG_ADDRESS = reg;
    YM2151_REG_DATA = data;
}

static void ym_configure_voice(uint8_t ch, const OPMVoice *voice) {
    // Global:

    // LFO:
    ym_write(0x18, voice->lfrq);
    ym_write(0x19, voice->amd & 0x7f);
    ym_write(0x19, voice->pmd | 0x80);
    ym_write(0x1b, voice->wf & 0x03);
    // CH included for NE
    ym_write(0x0f, voice->nfrq | voice->ne << 7);

    // Per channel:

    // CH:
    ym_write(0x20 + ch, voice->pan | voice->fl << 3 | voice->con);
    ym_write(0x38 + ch, voice->pms << 4 | voice->ams);

    // Operators:
    for (uint8_t i = 0; i < 4; i++) {
        uint8_t base = i * 8 + ch;
        const OPMOperator *op = &voice->operators[i];
        ym_write(0x40 + base, op->dt1 << 4 | op->mul);
        ym_write(0x60 + base, op->tl);
        ym_write(0x80 + base, op->ks << 6 | op->ar);
        ym_write(0xa0 + base, op->ame | op->d1r);
        ym_write(0xc0 + base, op->dt2 << 6 | op->d2r);
        ym_write(0xe0 + base, op->d1l << 4 | op->rr);
    }
}

static void ym_load_opm_bin(const uint8_t *opm_bin, OPMVoice *voice) {
    voice->lfrq = *opm_bin++;
    voice->amd = *opm_bin++;
    voice->pmd = *opm_bin++;
    voice->wf = *opm_bin++;
    voice->nfrq = *opm_bin++;

    voice->pan = *opm_bin++;
    voice->fl = *opm_bin++;
    voice->con = *opm_bin++;
    voice->ams = *opm_bin++;
    voice->pms = *opm_bin++;
    voice->slot_mask = *opm_bin++;
    voice->ne = *opm_bin++;

    for (uint8_t i = 0; i < 4; i++) {
        OPMOperator *op = &voice->operators[i];
        op->ar = *opm_bin++;
        op->d1r = *opm_bin++;
        op->d2r = *opm_bin++;
        op->rr = *opm_bin++;
        op->d1l = *opm_bin++;
        op->tl = *opm_bin++;
        op->ks = *opm_bin++;
        op->mul = *opm_bin++;
        op->dt1 = *opm_bin++;
        op->dt2 = *opm_bin++;
        op->ame = *opm_bin++;
    }
}
