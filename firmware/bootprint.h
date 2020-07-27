// bootprint.h
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#ifndef bootprint_h
#define bootprint_h

#include <stdint.h>

void bp_print_init(void);
void bp_print(uint16_t vram_start, const char *string);

void bp_print_greetings(void);

#endif /* bootprint_h */
