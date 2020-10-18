// status.c
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#include "status.h"

void status_set_leds(uint8_t val) {
    SYS_STATUS_LEDS = val;
}
