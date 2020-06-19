// flash_dma.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

`include "debug.vh"

module flash_dma (
    input clk,
    input reset,

    // CPU reads
    input [17:0] read_address,
    output [31:0] read_data,
    input read_en,
    // separate to the above; this is intended to stall the CPU
    output reg read_ready,

    // SPI flash
    output flash_sck,
    output flash_csn,
    output [3:0] flash_out,
    output [3:0] flash_oe,
    input [3:0] flash_in
);
    localparam FLASH_USER_BASE = 24'h100000;

    // --- CPU random access of flash memory ---

    reg read_en_r, read_en_d;

    reg cpu_needs_read, cpu_needs_read_d;

    reg [21:0] cpu_read_address;

    wire cpu_read_requested = (read_en_r && !read_en_d && !cpu_needs_read);
    wire cpu_requested_read_done = (cpu_needs_read && cpu_needs_read_d && flash_ready);

    always @(posedge clk) begin
        if (reset) begin
            read_ready <= 0;
            cpu_needs_read <= 0;
            read_en_r <= 0;
        end else begin
            // register CPU control (bad timing otherwise)
            read_en_r <= read_en;

            // stall cpu and start reading if a read was just requested
            if (cpu_read_requested) begin
                cpu_needs_read <= 1;
            end else if (cpu_requested_read_done) begin
                cpu_needs_read <= 0;
            end

            // resume cpu if read is done
            read_ready <= cpu_requested_read_done;
        end
    end

    always @(posedge clk) begin
        read_en_d <= read_en_r;
        cpu_needs_read_d <= cpu_needs_read;

        if (cpu_read_requested) begin
            cpu_read_address <= FLASH_USER_BASE + read_address;
        end
    end

    // --- Flash memory (16Mbyte - 1Mbyte) ---

    wire flash_ready;
    wire [31:0] flash_data_out;

    // the flash controller will hold rdata for a while as it reads the next 8bits from flash
    assign read_data = flash_data_out;

    icosoc_flashmem flash(
        .clk(clk),
        .resetn(!reset),

        .continue_reading(0),
        .valid(cpu_needs_read),
        .ready(flash_ready),
        .addr(cpu_read_address),
        .rdata(flash_data_out),
        
        .spi_cs(flash_csn),
        .spi_sclk(flash_sck),
        .flash_out(flash_out),
        .flash_in(flash_in),
        .flash_oe(flash_oe)
    );

endmodule
