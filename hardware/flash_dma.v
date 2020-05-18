// flash_dma.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

`include "debug.vh"

// this is being minimised when the BRAM-based software IPL is added
// that would make this hardware IPL redundant

module flash_dma(
    input clk,
    input reset,

    // CPU reads
    input [17:0] read_address,
    output [31:0] read_data,
    input read_en,
    // separate to the above; this is intended to stall the CPU
    output reg read_ready,

    // IPL DMA - writing to RAM for now but eventually anything else (shared bus)
    output reg [31:0] write_address,
    output [31:0] write_data,

    // mimic picorv32 wstrb
    output reg [3:0] write_strobe,

    // only used for IPL on startup to take control of bus
    output reg dma_busy,

    // SPI flash
    output flash_sck,
    output flash_csn,
    output flash_mosi,
    input flash_miso
);
    localparam FLASH_USER_BASE = 24'h100000;

    // IPL parameters

    localparam FLASH_LOAD_BASE = 24'h100000;
    localparam FLASH_LOAD_LENGTH = 16'he800;
    localparam FLASH_WRITE_BASE = 16'h0000;

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

    // --- IPL DMA reader ---

    reg [20:0] flash_read_index;

    reg flash_loading;

    reg flash_write_data_ready;
    reg flash_write_ready_next;

    reg [13:0] flash_read_counter;
    reg [13:0] flash_read_length;

    wire flash_input_valid = flash_ready && flash_loading;
    wire flash_end_reached = flash_read_counter == flash_read_length;

    // this reads an arbitrary number of bytes from flash controller
    // then signals availability to the RAM writer below
    always @(posedge clk) begin
        if (reset) begin
            flash_read_index <= FLASH_LOAD_BASE;
            flash_read_length <= FLASH_LOAD_LENGTH / 4;

            flash_read_counter <= 0;
            flash_loading <= 1;
            flash_write_data_ready <= 0;
        end else begin
            flash_write_data_ready <= 0;

            if (flash_input_valid && flash_write_ready_next) begin
                if (!flash_end_reached) begin
                    flash_read_counter <= flash_read_counter + 1;
                    flash_write_data_ready <= 1;
                end else begin
                    flash_loading <= 0;
                end
            end
        end
    end

    // --- IPL DMA writer ---

    // this is probably getting removed in favour of just using 2x BRAM to store a bootloader
    // then this doesn't need to be here and the SPRAM data / address selection can be removed
    // there is a tradeoff as extra LUTs are needed on the CPU rdata but it does provide extra scratchpad 

    always @(posedge clk) begin
        if (reset) begin
            write_strobe <= 0;
            flash_write_ready_next <= 1'b1;
            write_address <= FLASH_WRITE_BASE[15:2];

            dma_busy <= 1;
        end else begin
            write_strobe <= 0;
            flash_write_ready_next <= 1;

            // post-increment address after each write
            if (write_strobe[0]) begin
                write_address <= write_address + 1;
            end

            if (flash_write_data_ready) begin
                flash_write_ready_next <= 0;
                write_strobe <= 4'b1111;
            end

            if (!flash_loading) begin
                // IPL is done so hand over control to CPU
                dma_busy <= 0;
            end
        end
    end

    // --- Flash memory (16Mbyte - 1Mbyte) ---

    wire [23:0] flash_address;
    wire flash_valid;
    wire flash_continue;

    wire flash_source_dma = dma_busy;

    always @* begin
        flash_address = flash_source_dma ? flash_read_index : cpu_read_address;
        flash_valid = flash_source_dma ? flash_loading : cpu_needs_read;
        flash_continue = flash_source_dma;
    end

    wire flash_ready;

    wire [31:0] flash_data_out;

    // the flash controller will hold rdata for a while as it reads the next 8bits from flash
    assign write_data = flash_data_out;
    assign read_data = flash_data_out;

    icosoc_flashmem flash(
        .clk(clk),
        .resetn(!reset),

        .continue_reading(flash_continue),
        .valid(flash_valid),
        .ready(flash_ready),
        .addr(flash_address),
        .rdata(flash_data_out),
        
        .spi_cs(flash_csn),
        .spi_sclk(flash_sck),
        .spi_mosi(flash_mosi),
        .spi_miso(flash_miso)
    );

endmodule
