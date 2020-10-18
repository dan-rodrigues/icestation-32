// status.h
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#ifndef status_h
#define status_h

#include <stdint.h>
#include <stdbool.h>

static volatile void *const SYS_STATUS_BASE = (uint32_t *)0x20000;
typedef volatile uint32_t *const SYS_STATUS_REG;

#define SYS_STATUS_LEDS (*((SYS_STATUS_REG)SYS_STATUS_BASE + 0))

// Sets the status leds on the board. Takes a bitmask.
void status_set_leds(uint8_t val);

#endif
