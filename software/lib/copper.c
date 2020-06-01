#include "copper.h"

#include <stddef.h>

#include "assert.h"

// volatile is strictly correct here considering a coprocessor is reading this
// in practice it might not matter by the time the function returns
static volatile uint16_t * const COP_RAM = (uint16_t *)0x50000;
static const size_t COP_RAM_SIZE = 0x1000 / sizeof(uint16_t);

static uint16_t cop_pc = 0;

static const uint8_t OP_SHIFT = 14;

// 2bit ops
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
    op_word |= target;
    COP_RAM[cop_pc++] = op_word;
}

void cop_write(VDP_REG reg, uint16_t data) {
    COPBatchWriteConfig config = {
        .mode = CWM_SINGLE,
        .reg = reg,
        .batch_count = 0,
        .batch_wait_between_lines = false
    };

    cop_start_batch_write(&config);
    cop_add_batch_single(&config, data);
}

void cop_write_compressed(VDP_REG reg, uint8_t data, bool increment_target_y) {
    uint16_t op_word = WRITE_COMPRESSED << OP_SHIFT;
    op_word |= cop_reg(reg);
    op_word |= data << 6;
    op_word |= increment_target_y ? 1 << 11 : 0;
    COP_RAM[cop_pc++] = op_word;
}

void cop_jump(uint16_t address) {
    assert(address < COP_RAM_SIZE);

    uint16_t op_word = JUMP << OP_SHIFT;
    op_word |= address;
    COP_RAM[cop_pc++] = op_word;
}

// batch writes

void cop_start_batch_write(COPBatchWriteConfig *config) {
    uint16_t op_word = WRITE_REG << OP_SHIFT;
    op_word |= cop_reg(config->reg);
    op_word |= config->batch_count << 6;
    op_word |= config->batch_wait_between_lines ? 1 << 11 : 0;
    op_word |= config->mode << 12;
    COP_RAM[cop_pc++] = op_word;

    config->batches_written = 0;
}

void cop_add_batch_single(COPBatchWriteConfig *config, uint16_t data) {
    assert(config->batches_written <= config->batch_count);
    assert(config->mode == CWM_SINGLE);

    COP_RAM[cop_pc++] = data;

    config->batches_written++;
}

void cop_add_batch_double(COPBatchWriteConfig *config, uint16_t data0, uint16_t data1) {
    assert(config->batches_written <= config->batch_count);
    assert(config->mode == CWM_DOUBLE);

    COP_RAM[cop_pc++] = data0;
    COP_RAM[cop_pc++] = data1;

    config->batches_written++;
}

void cop_add_batch_quad(COPBatchWriteConfig *config, uint16_t data0, uint16_t data1, uint16_t data2, uint16_t data3) {
    assert(config->batches_written <= config->batch_count);
    assert(config->mode == CWM_QUAD);

    COP_RAM[cop_pc++] = data0;
    COP_RAM[cop_pc++] = data1;
    COP_RAM[cop_pc++] = data2;
    COP_RAM[cop_pc++] = data3;

    config->batches_written++;
}

void cop_signal(uint8_t data) {
    COP_RAM[cop_pc++] = data;
}

static uint8_t cop_reg(VDP_REG reg) {
    return ((uint32_t)reg / 2) & 0x3f;
}
