// bus_arbiter.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module bus_arbiter #(
    parameter SUPPORT_2X_CLK = 0
) (
    input clk,

    // CPU inputs
    input [3:0] cpu_wstrb,
    input [15:0] cpu_address,
    input [31:0] cpu_write_data,
    
    // DMA inputs
    input [15:0] dma_address,
    input [31:0] dma_write_data,
    input [3:0] dma_wstrb,
    input dma_busy,

    // address decoder inputs
    input cpu_ram_write_en,
    input vdp_en,
    input flash_read_en,
    input cpu_ram_en,
    input dsp_en,
    input status_en,

    // ready inputs from read sources
    input flash_read_ready,
    input vdp_ready,

    // data inputs from read sources
    input [31:0] cpu_ram_read_data,
    input [31:0] flash_read_data,
    input [15:0] vdp_read_data,
    input [31:0] dsp_read_data,

    // CPU outputs
    output reg cpu_mem_ready,
    output [31:0] cpu_read_data,

    // RAM outputs
    output [31:0] cpu_ram_write_data,
    output [15:0] cpu_ram_address,
    output [3:0] cpu_ram_wstrb,
    output cpu_ram_cs,
    output cpu_ram_wren
);
    assign cpu_ram_wstrb = dma_busy ? 4'hf : {
        cpu_wstrb[3],
        cpu_wstrb[2],
        cpu_wstrb[1],
        cpu_wstrb[0]
    };

    assign cpu_ram_wren = dma_busy ? |dma_wstrb : cpu_ram_write_en;
    assign cpu_ram_cs = dma_busy ? 1'b1 : cpu_ram_en;

    assign cpu_ram_write_data = dma_busy ? dma_write_data : cpu_write_data;
    assign cpu_ram_address = dma_busy ? dma_address : cpu_address[15:2];

    wire cpu_ram_ready, peripheral_ready;

    generate
        // using !cpu_mem_ready only works if the CPU clk is full speed
        if (!SUPPORT_2X_CLK) begin
            assign cpu_ram_ready = cpu_ram_en && !cpu_mem_ready;
            assign peripheral_ready = ((vdp_en && vdp_ready) || status_en || dsp_en) && !cpu_mem_ready;
        end else begin
            assign cpu_ram_ready = cpu_ram_en;
            assign peripheral_ready = ((vdp_en && vdp_ready) || status_en || dsp_en);
        end
    endgenerate

    always @(posedge clk) begin
        if (dma_busy) begin
            cpu_mem_ready <= 0;
        end else begin
            cpu_mem_ready <= cpu_ram_ready || flash_read_ready || peripheral_ready;
        end
    end

    // needs registering due to timing
    reg flash_read_en_r;

    always @(posedge clk) begin
        flash_read_en_r <= flash_read_en;
    end

    wire [31:0] cpu_ram_read_data_ps, cpu_read_data_s;
    assign cpu_read_data = cpu_read_data_s;

    always @* begin
        if (flash_read_en_r) begin
            cpu_ram_read_data_ps = flash_read_data;
        end else if (vdp_en) begin
            // FIXME: no read to double the data bus here
            // so long as the read addresses are 32bit aligned
            // cpu_read_data = {{16{1'bx}}, vdp_read_data};

            cpu_ram_read_data_ps = {2{vdp_read_data}};
        end else if (dsp_en) begin
            cpu_ram_read_data_ps = dsp_read_data;
        end else begin
            // default to reading RAM
            cpu_ram_read_data_ps = cpu_ram_read_data;
        end
    end

    generate
        if (SUPPORT_2X_CLK) begin
            reg [31:0] cpu_read_data_r;
            assign cpu_read_data_s = cpu_read_data_r;

            always @(posedge clk) begin
                cpu_read_data_r <= cpu_ram_read_data_ps;
            end
        end else begin
            assign cpu_read_data_s = cpu_ram_read_data_ps;
        end
    endgenerate

endmodule
