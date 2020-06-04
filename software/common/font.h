// font.h
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#ifndef font_h
#define font_h

void upload_font(uint16_t vram_base);
void upload_font_remapped(uint16_t vram_base, uint8_t transparent, uint8_t opaque);

#endif /* font_h */
