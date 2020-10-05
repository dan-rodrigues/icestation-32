// cpu_peripheral_sync.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module cpu_peripheral_sync(
    input clk_1x,
    input clk_2x,

    // 1x inputs
    input [3:0] cpu_wstrb,
    input [31:0] cpu_address,
    input [31:0] cpu_write_data,
    input cpu_mem_valid,

    // 2x inputs
    input cpu_mem_ready,
    input [31:0] cpu_read_data,

    output reg [3:0] cpu_wstrb_2x,
    output reg [31:0] cpu_write_data_2x,
    output reg [31:0] cpu_address_2x,
    output reg cpu_mem_valid_2x,

    output reg cpu_mem_ready_1x,
    output reg [31:0] cpu_read_data_1x
);

    // --- 1x -> 2x ---

    always @(negedge clk_2x) begin
        cpu_write_data_2x <= cpu_write_data;
        cpu_address_2x <= cpu_address;
        cpu_wstrb_2x <= cpu_wstrb;
        cpu_mem_valid_2x <= cpu_mem_valid;
    end

    // --- 2x -> 1x ---

    reg [31:0] cpu_read_data_r;
    reg cpu_mem_ready_r, cpu_mem_ready_d;

    reg cpu_mem_ready_rose, cpu_mem_ready_rose_r;

    always @(negedge clk_2x) begin
        cpu_read_data_r <= cpu_read_data;

        cpu_mem_ready_r <= cpu_mem_ready;
        cpu_mem_ready_d <= cpu_mem_ready_r;
        cpu_mem_ready_rose <= cpu_mem_ready_r && !cpu_mem_ready_d;
        cpu_mem_ready_rose_r <= cpu_mem_ready_rose;
    end

    // eliminating this stage causes problems
    // negedge 2x clk -> posedge 1x clk gives these signals half a 2x clk cycle to propagate through CPU

    always @(posedge clk_1x) begin
        cpu_read_data_1x <= cpu_read_data_r;
        cpu_mem_ready_1x <= cpu_mem_ready_rose || cpu_mem_ready_rose_r;
    end

endmodule
