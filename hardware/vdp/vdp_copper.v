// vdp_copper.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module vdp_copper(
    input clk,
    input reset,

    input enable,

    // Raster tracking

    input [10:0] raster_x,
    input [9:0] raster_y,

    // RAM interface

    output reg [10:0] ram_read_address,
    input [15:0] ram_read_data,

    // Register interface

    output reg [5:0] reg_write_address,
    output reg [15:0] reg_write_data,
    output reg reg_write_en,
    input reg_write_ready
);
    localparam PC_RESET = 10'h000;

    reg [10:0] pc;

    assign ram_read_address = pc;

    // wire [10:0] pc_nx;

    // --- Raster tracking ---

    reg [10:0] target_x;
    reg [9:0] target_y;

    wire target_hit = (target_x == raster_x && target_y == raster_y);

    // --- Ops ---

    // ooo----- --------
    // o: 3bit op
    // -: op defined fields

    wire [2:0] op = ram_read_data[15:13];
    reg [2:0] op_current;

    localparam OP_SET_TARGET = 2'h0;
    localparam OP_WAIT_TARGET = 2'h1;
    localparam OP_WRITE_REG = 2'h2;
    localparam OP_JUMP = 2'h3;

    // SET_TARGET / WAIT_TARGET

    // oo--wsvv vvvvvvvv
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

    // oo------ --rrrrrr
    //
    // r: target register
    // ?: fields to alter how the writes are managed

    // the preceeding op must have ram_read_data ready

    // TODO: break this up accordingly

    localparam STATE_OP_FETCH = 0;
    localparam STATE_DATA_FETCH = 1;
    localparam STATE_RASTER_WAITING = 2;

    reg [1:0] state;

    always @(posedge clk) begin
        if (reset || !enable) begin
            pc <= PC_RESET;
            reg_write_en <= 0;
            state <= STATE_OP_FETCH;
        end else begin
            reg_write_en <= 0;

            if (state == STATE_OP_FETCH) begin
                // decode op (already fetched)
                case (op)
                    OP_SET_TARGET, OP_WAIT_TARGET: begin
                        if (op_target_select) begin
                            target_y <= op_target_value;
                        end else begin
                            target_x <= op_target_value;
                        end

                        if (op_target_wait) begin
                            state <= STATE_RASTER_WAITING;
                        end else begin
                            state <= STATE_OP_FETCH;
                            pc <= pc + 1;
                        end
                    end
                    OP_WRITE_REG: begin
                        reg_write_address <= ram_read_data[5:0];
                        state <= STATE_DATA_FETCH;
                        pc <= pc + 1;
                    end
                    OP_JUMP: begin
                        pc <= ram_read_data[10:0];
                    end
                endcase

                op_current <= op;
            end else if (state == STATE_DATA_FETCH) begin
                case (op_current)
                    OP_WRITE_REG: begin
                        reg_write_data <= ram_read_data;
                        reg_write_en <= 1;
                        state <= STATE_OP_FETCH;
                    end
                endcase

                pc <= pc + 1;
            end else if (state == STATE_RASTER_WAITING) begin
                if (target_hit) begin
                    state <= STATE_OP_FETCH;
                    pc <= pc + 1;
                end
            end
        end
    end

endmodule

// TODO: some formal verification here
