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

    localparam OP_SET_TARGET_X = 3'h0;
    localparam OP_WAIT_TARGET_Y = 3'h1;
    // ...
    localparam OP_WRITE_REG = 3'h2;

    // ooo----- --rrrrrr
    // r: register
    // ?:

    // the preceeding op must have ram_read_data ready

    // TODO: break this up accordingly

    localparam STATE_OP_FETCH = 0;
    localparam STATE_DATA_FETCH = 1;
    localparam STATE_RASTER_WAITING = 2;

    reg [1:0] state;

    always @(posedge clk) begin
        if (reset) begin
            pc <= PC_RESET;
            reg_write_en <= 0;
            state <= STATE_OP_FETCH;
        end else begin
            // pc <= pc_nx;
        end

        reg_write_en <= 0;

        // wrapping the whole thing in an if is simple but inefficient, refine later
        if (enable) begin
            if (state == STATE_OP_FETCH) begin
                // decode op (already fetched)
                case (op)
                    OP_SET_TARGET_X: begin
                        target_x <= ram_read_data[10:0];
                        pc <= pc + 1;
                    end
                    OP_WAIT_TARGET_Y: begin
                        target_y <= ram_read_data[9:0];
                        state <= STATE_RASTER_WAITING;
                    end
                    OP_WRITE_REG: begin
                        reg_write_address <= ram_read_data[5:0];
                        state <= STATE_DATA_FETCH;
                        pc <= pc + 1;
                    end
                endcase

                // fetch next op (or data)
                // pc <= pc + 1;
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
