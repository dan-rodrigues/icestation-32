// copper.c
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#include "copper.h"

#include <stddef.h>

#include "assert.h"

// volatile is strictly correct here considering a separate coprocessor is reading this
// in practice it might not matter by the time the function returns
static volatile uint16_t * const COP_RAM = (uint16_t *)0x50000;
static const size_t COP_RAM_SIZE = 0x1000 / sizeof(uint16_t);

static uint32_t cop_pc = 0;

static const uint8_t OP_SHIFT = 14;

typedef enum {
    SET_TARGET = 0,
    WRITE_COMPRESSED = 1,
    WRITE_REG = 2,
    JUMP = 3
} Op;

static void cop_target(uint16_t target, bool is_y, bool wait);
static uint8_t cop_reg(VDP_REG reg);

void cop_ram_seek(uint16_t address) {
    assert(address < COP_RAM_SIZE);

    cop_pc = address;
}

uint16_t cop_ram_get_write_index(void) {
    return cop_pc;
}

void cop_set_target_x(uint16_t target_x) {
    cop_target(target_x, false, false);
}

void cop_set_target_y(uint16_t target_y) {
    cop_target(target_y, true, false);
}

void cop_wait_target_x(uint16_t target_x) {
    cop_target(target_x, false, true);
}

void cop_wait_target_y(uint16_t target_y) {
    cop_target(target_y, true, true);
}

static void cop_target(uint16_t target, bool is_y, bool wait) {
    uint16_t op_word = SET_TARGET << OP_SHIFT;
    op_word |= is_y ? 1 << 11 : 0;
    op_word |= wait ? 1 << 12 : 0;
    op_word |= target & 0x7ff;
    COP_RAM[cop_pc++] = op_word;
}

void cop_write(VDP_REG reg, uint16_t data) {
    COPBatchWriteConfig config = {
        .mode = CWM_SINGLE,
        .reg = reg,
        .batch_count = 1,
        .batch_wait_between_lines = false
    };

    cop_start_batch_write(&config);
    cop_add_batch_single(&config, data);
}

void cop_write_compressed(VDP_REG reg, uint8_t data, bool increment_target_y) {
    uint16_t op_word = WRITE_COMPRESSED << OP_SHIFT;
    op_word |= cop_reg(reg);
    op_word |= (data & 0x1f) << 6;
    op_word |= increment_target_y ? 1 << 11 : 0;
    COP_RAM[cop_pc++] = op_word;
}

void cop_jump(uint16_t address) {
    assert(address < COP_RAM_SIZE);

    uint16_t op_word = JUMP << OP_SHIFT;
    op_word |= address & 0x7ff;
    COP_RAM[cop_pc++] = op_word;
}

// batch writes

void cop_start_batch_write(COPBatchWriteConfig *config) {
    assert(config->batch_count > 0);
    assert(config->batch_count <= 32);

    uint16_t op_word = WRITE_REG << OP_SHIFT;
    op_word |= cop_reg(config->reg);
    op_word |= (config->batch_count - 1) << 6;
    op_word |= config->batch_wait_between_lines ? 1 << 11 : 0;
    op_word |= config->mode << 12;
    COP_RAM[cop_pc++] = op_word;

    config->batches_written = 0;
}

void cop_add_batch_single(COPBatchWriteConfig *config, uint16_t data) {
    COP_RAM[cop_pc++] = data;

    config->batches_written++;
}

void cop_add_batch_double(COPBatchWriteConfig *config, uint16_t data0, uint16_t data1) {
    COP_RAM[cop_pc++] = data0;
    COP_RAM[cop_pc++] = data1;

    config->batches_written++;
}

void cop_add_batch_quad(COPBatchWriteConfig *config, uint16_t data0, uint16_t data1, uint16_t data2, uint16_t data3) {
    COP_RAM[cop_pc++] = data0;
    COP_RAM[cop_pc++] = data1;
    COP_RAM[cop_pc++] = data2;
    COP_RAM[cop_pc++] = data3;

    config->batches_written++;
}

static uint8_t cop_reg(VDP_REG reg) {
    return ((uint32_t)reg / 2) & 0x3f;
}

void cop_assert_config_consistent(const COPBatchWriteConfig *config) {
    assert(config->batches_written < config->batch_count);
}
