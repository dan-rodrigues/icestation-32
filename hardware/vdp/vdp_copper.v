// vdp_copper.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`include "debug.vh"

`default_nettype none

module vdp_copper(
    input clk,
    input reset,

    input enable,

    // Raster tracking

    input [10:0] raster_x,
    input [9:0] raster_y,

    // RAM interface

    output [10:0] ram_read_address,
    output ram_read_en,
    input [15:0] ram_read_data,

    // Register interface

    output reg [4:0] reg_write_address,
    output reg [15:0] reg_write_data,
    output reg reg_write_en
);
    localparam PC_RESET = 10'h000;

    wire operating = !reset && enable;

    reg [10:0] pc;
    assign ram_read_address = pc;

    reg ram_read_deferring;
    assign ram_read_en = operating && !ram_read_deferring;

    // --- Raster tracking ---

    reg [10:0] target_x;
    reg [9:0] target_y;

    wire target_hit = (target_x == raster_x && target_y == raster_y);

    // --- Ops ---

    // oo------ --------
    // o: 2bit op
    // remaining fields are op-defined

    wire [1:0] op = ram_read_data[15:14];
    reg [1:0] op_current;

    localparam OP_SET_TARGET = 2'h0;
    localparam OP_WRITE_COMPRESSED = 2'h1;
    localparam OP_WRITE_REG = 2'h2;
    localparam OP_JUMP = 2'h3;

    // SET_TARGET / WAIT_TARGET

    // oo-wsvvv vvvvvvvv
    //
    // v: raster x/y value
    // s:
    //      0: select x
    //      1: select y
    // w:
    //      0: don't wait, immediately advance to next op
    //      1: wait until raster x/y reaches the target before advancing to next op

    wire op_target_wait = ram_read_data[12];
    wire op_target_select = ram_read_data[11];
    wire [10:0] op_target_value = ram_read_data[10:0];

    // REG_WRITE

    // ooiiynnn nn-rrrrr
    //
    // r: target register
    // n: number of batches write
    // i: reg increment mode (batch size)
    //      0: reg[0], repeat
    //      1: reg[0], reg[1], repeat
    //      2: reg[0], reg[1], reg[2], reg[3], repeat
    // y: autoincrement target Y and wait between batches

    wire [4:0] op_write_target_reg = ram_read_data[4:0];
    wire [4:0] op_write_batch_count = ram_read_data[10:6];
    wire op_write_auto_wait = ram_read_data[11];
    wire [1:0] op_write_increment_mode = ram_read_data[13:12];

    reg [4:0] op_write_target_reg_r;
    reg [4:0] op_write_batch_count_r;
    reg op_write_auto_wait_r;
    reg [1:0] op_write_increment_mode_r;

    // working state

    reg [1:0] op_write_counter;
    reg [1:0] op_write_reg_offset;

    always @* begin
        case (op_write_increment_mode_r)
            0: op_write_reg_offset = 0;
            1: op_write_reg_offset = op_write_counter & 2'b01;
            2: op_write_reg_offset = op_write_counter & 2'b11;
            3: begin
                op_write_reg_offset = 0;
                `stop($display("unexpected state");)
            end
        endcase
    end

    reg op_write_batch_complete;

    always @* begin
        case (op_write_increment_mode_r)
            0: op_write_batch_complete = 1;
            1: op_write_batch_complete = op_write_counter & 1;
            2: op_write_batch_complete = op_write_counter == 2'b11;
            3: begin
                op_write_batch_complete = 1;
                `stop($display("unexpected state");)
            end
        endcase
    end

    // REG_WRITE_COMPRESSED

    // oo--yddd ddrrrrrr
    //
    // r: target register
    // d: data to write
    // y: autoincrement target Y (then automatically continue)

    wire [5:0] op_write_compressed_reg = ram_read_data[5:0];
    wire [15:0] op_write_compressed_data = ram_read_data[10:6];
    wire op_write_compressed_auto_increment_y = ram_read_data[11];

    // JUMP

    wire [10:0] op_jump_target = ram_read_data[10:0];

    // --- FSM ---

    localparam STATE_OP_DECODE = 0;
    localparam STATE_DATA_FETCH = 1;
    localparam STATE_RASTER_WAITING = 2;
    localparam STATE_OP_PREFETCH = 3;

    reg [1:0] state;

    always @(posedge clk) begin
        if (!operating) begin
            pc <= PC_RESET;

            reg_write_en <= 0;

            target_x <= 0;
            target_y <= 0;
            state <= STATE_OP_PREFETCH;

            ram_read_deferring <= 0;
        end else begin
            reg_write_en <= 0;

            if (state == STATE_OP_DECODE) begin
                case (op)
                    OP_SET_TARGET: begin
                        if (op_target_select) begin
                            target_y <= op_target_value;
                        end else begin
                            target_x <= op_target_value;
                        end

                        state <= (op_target_wait ? STATE_RASTER_WAITING : STATE_OP_DECODE);

                        if (op_target_wait) begin
                            ram_read_deferring <= 1;
                        end

                        pc <= pc + 1;
                    end
                    OP_WRITE_REG: begin
                        op_write_target_reg_r <= op_write_target_reg;
                        op_write_batch_count_r <= op_write_batch_count;
                        op_write_auto_wait_r <= op_write_auto_wait;
                        op_write_increment_mode_r <= op_write_increment_mode;

                        op_write_counter <= 0;

                        state <= STATE_DATA_FETCH;
                        pc <= pc + 1;
                    end
                    OP_JUMP: begin
                        pc <= op_jump_target;
                        state <= STATE_OP_PREFETCH;
                    end
                    OP_WRITE_COMPRESSED: begin
                        reg_write_address <= op_write_compressed_reg;
                        reg_write_data <= op_write_compressed_data;
                        reg_write_en <= 1;

                        if (op_write_compressed_auto_increment_y) begin
                            target_y <= raster_y + 1;
                        end

                        pc <= pc + 1;
                    end
                endcase

                op_current <= op;
            end else if (state == STATE_DATA_FETCH) begin
                reg_write_data <= ram_read_data;
                reg_write_address <= op_write_target_reg_r + op_write_reg_offset;
                reg_write_en <= 1;

                op_write_counter <= op_write_counter + 1;

                if (op_write_batch_complete) begin
                    if (op_write_batch_count_r == 0) begin
                        state <= STATE_OP_DECODE;
                    end else begin
                        op_write_batch_count_r <= op_write_batch_count_r - 1;

                        if (op_write_auto_wait_r) begin
                            target_y <= raster_y + 1;
                            ram_read_deferring <= 1;
                            state <= STATE_RASTER_WAITING;
                        end
                    end
                end

                pc <= pc + 1;
            end else if (state == STATE_RASTER_WAITING) begin
                if (target_hit) begin
                    if (op_current == OP_WRITE_REG && op_write_auto_wait_r) begin
                        state <= STATE_DATA_FETCH;
                    end else begin
                        state <= STATE_OP_DECODE;
                    end

                    ram_read_deferring <= 0;
                end
            end else if (state == STATE_OP_PREFETCH) begin
                state <= STATE_OP_DECODE;
            end
        end
    end

endmodule
