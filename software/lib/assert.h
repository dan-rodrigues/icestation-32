// assert.h
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#ifndef assert_h
#define assert_h

#include <stdbool.h>
#include <stdnoreturn.h>

#define assert(condition) assert_impl(condition, __FILE__, __LINE__, #condition)
#define fatal_error(message) fatal_error_impl(__FILE__, __LINE__, message)

typedef void (*AssertHandler)(const char *file, int line, const char *message);

void assert_impl(bool assertion, const char *file, int line, const char *message);
noreturn void fatal_error_impl(const char *file, int line, const char *message);

void assert_set_handler(AssertHandler handler);

#endif /* assert_h */
