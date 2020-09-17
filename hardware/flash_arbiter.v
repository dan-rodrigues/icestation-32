// flash_arbiter.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

`include "debug.vh"

module flash_arbiter(
    input clk,
    input reset,

    input [23:0] read_address_a,
    input read_en_a,
    input size_a,
    output reg ready_a,
    
    input [23:0] read_address_b,
    input read_en_b,
    input size_b,
    output reg ready_b,

    output [31:0] read_data,

    // QSPI flash
    
    output flash_clk_en,
    output flash_csn,
    output [3:0] flash_in,
    output [3:0] flash_in_en,
    input [3:0] flash_out
);
    localparam [23:0] FLASH_USER_BASE = 24'h200000;

    // --- Arbitration between reader A/B ---

    localparam [0:0]
        READER_A = 1,
        READER_B = 0;

    reg reader_selected;
    reg read_active;

    reg read_en_a_r, read_en_b_r;
    reg read_en_a_edge, read_en_b_edge;

    always @(posedge clk) begin
        read_en_a_r <= read_en_a;
        read_en_b_r <= read_en_b;
        read_en_a_edge <= (read_en_a && !read_en_a_r) || read_en_a_edge;
        read_en_b_edge <= (read_en_b && !read_en_b_r) || read_en_b_edge;

        ready_a <= 0;
        ready_b <= 0;

        // Is either reader waiting?

        if (!read_active) begin
            // Prioritize B if there is a double read in same cycle
            if (read_en_b_edge) begin
                reader_selected <= READER_B;
                read_active <= 1;
                read_en_b_edge <= 0;
            end else if (read_en_a_edge) begin
                reader_selected <= READER_A;
                read_active <= 1;
                read_en_a_edge <= 0;
            end
        end

        // Is read done?

        if (flash_ready) begin
            if (reader_selected == READER_A) begin
                ready_a <= 1;
            end else begin
                ready_b <= 1;
            end

            read_active <= 0;
        end

        if (reset) begin
            read_active <= 0;
        end
    end

    // --- Register flash reader inputs ---

    reg [23:0] flash_read_address;
    reg flash_read_en;
    reg flash_read_size;

    always @(posedge clk) begin
        flash_read_address <= (reader_selected ? read_address_a : read_address_b) + FLASH_USER_BASE;
        flash_read_en <= (reader_selected ? read_en_a : read_en_b) && read_active;
        flash_read_size <= (reader_selected ? size_a : size_b);
    end

    // --- Flash memory (16Mbyte - 1Mbyte) ---

    wire flash_ready;

    flash_reader flash_reader(
        .clk(clk),
        .reset(reset),

        .valid(flash_read_en),
        .size(flash_read_size),
        .address(flash_read_address),

        .data(read_data),
        .ready(flash_ready),
        
        .flash_clk_en(flash_clk_en),
        .flash_csn(flash_csn),
        .flash_out(flash_out),
        .flash_in(flash_in),
        .flash_in_en(flash_in_en)
    );

endmodule
