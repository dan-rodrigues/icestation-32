// assert.c
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#include "assert.h"

static AssertHandler custom_handler;

void assert_impl(bool assertion, const char *file, int line, const char *message) {
#ifdef ASSERT_ENABLED
    if (assertion) {
        return;
    }

    if (custom_handler) {
        custom_handler(file, line, message);
    } else {
        __asm("ebreak");
    }
#endif
}

noreturn void fatal_error_impl(const char *file, int line, const char *message) {
    assert_impl(false, file, line, message);
    while(true) {}
}

void assert_set_handler(AssertHandler handler) {
    custom_handler = handler;
}
