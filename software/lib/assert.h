// assert.h
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#ifndef assert_h
#define assert_h

#include <stdbool.h>
#include <stdnoreturn.h>

#define assert(x) assert_impl(x, __FILE__, __LINE__)
#define fatal_error() fatal_error_impl(__FILE__, __LINE__)

typedef void (*AssertHandler)(const char *file, int line);

void assert_impl(bool assertion, const char *file, int line);
noreturn void fatal_error_impl(const char *file, int line);

void assert_set_handler(AssertHandler handler);

#endif /* assert_h */
