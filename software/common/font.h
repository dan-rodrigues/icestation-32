// font.h: Convert 8x8 1bpp font tiles to the required 4bpp color format.
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#ifndef font_h
#define font_h

// Upload a 128-character ASCII font at vram_base.
void upload_font(uint16_t vram_base);

// Upload a minimal uppercase latin only font at vram_base.
void upload_font_minimal(uint16_t vram_base);

// Upload a default 128-character ASCII font at vram_base, providing a color
// 0..15 to use for foreground and background.
void upload_font_remapped(uint16_t vram_base, uint8_t transparent, uint8_t opaque);

// Upload a specified font with specified number of characters at vram_base,
// providing a color 0..15 to use for foreground and background.
void upload_font_remapped_main(uint16_t vram_base, uint8_t transparent, uint8_t opaque, const char font[][8], uint16_t char_total);

#endif /* font_h */
