// vdp_host_interface.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

`include "debug.vh"

module vdp_host_interface(
    input clk,
    input reset,

    input [5:0] host_address,
    output reg [4:0] register_write_address,
    input vram_write_pending,

    // Writes..

    output reg register_write_en,
    output reg [15:0] register_write_data,
    output reg ready,

    // ..from CPU

    input host_write_en,
    input [15:0] host_write_data,
    
    // ..from copper

    input cop_write_en,
    input [4:0] cop_write_address,
    input [15:0] cop_write_data,

    // Reads (only from CPU)

    input host_read_en,
    output reg [4:0] read_address
);
    reg host_write_en_r;
    reg host_write_pending;
    reg host_read_en_r;

    wire host_write_en_gated = host_write_en && !host_write_pending && !vram_write_pending;

    always @(posedge clk) begin
        host_write_en_r <= host_write_en;
        host_read_en_r <= host_read_en;
    end

    always @(posedge clk) begin
        // Reads use the registered input as a 1 cycle delay is required before output valid
        // Writes only need to be delayed if a subsequent write risks clobbering VRAM
        ready <= (host_write_en_gated || host_read_en_r);
    end

    always @(posedge clk) begin
        if (reset) begin
            register_write_en <= 0;
        end else begin
            register_write_en <= cop_write_en || host_write_en_gated;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            host_write_pending <= 0;
        end else if (host_write_en_gated) begin
            host_write_pending <= 1;
        end else if (!host_write_en) begin
            host_write_pending <= 0;
        end
    end

    always @(posedge clk) begin
        if (host_write_en) begin
            register_write_address <= host_address;
            register_write_data <= host_write_data;
        end else begin
            register_write_address <= cop_write_address;
            register_write_data <= cop_write_data;
        end

        // CPU is always free to read
        read_address <= host_address;
    end

    always @(posedge clk) begin
        if (!reset && cop_write_en && host_write_en) begin
            // Must be a software or hardware bug so flag it accordingly
            `stop($display("CPU / VDP copper write conflict. CPU: %x, COP: %x", host_address, cop_write_address);)
        end
    end

endmodule
