// assert.c
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#include "assert.h"

static AssertHandler custom_handler;

void assert_impl(bool assertion, const char *file, int line) {
#ifdef ASSERT_ENABLED
    if (assertion) {
        return;
    }

    if (custom_handler) {
        custom_handler(file, line);
    } else {
        __asm("ebreak");
    }
#endif
}

noreturn void fatal_error_impl(const char *file, int line) {
    assert_impl(false, file, line);
    while(true) {}
}

void assert_set_handler(AssertHandler handler) {
    custom_handler = handler;
}
