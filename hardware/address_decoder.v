// address_decoder.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

// minimising to 512k for now
// will likely be increased soon

module address_decoder #(
    parameter SUPPORT_2X_CLK = 0
) (
    input clk,
    input reset,

    input [18:0] cpu_address,
    input cpu_mem_valid,
    input [3:0] cpu_wstrb,

    output reg vdp_en,
    output reg vdp_write_en,

    output reg cpu_ram_en,

    output reg status_en,
    output reg status_write_en,

    output reg flash_read_en,

    output reg dsp_en,
    output reg dsp_write_en
);
    wire [18:0] cpu_address_s;
    wire cpu_mem_valid_s;
    wire [3:0] cpu_wstrb_s;

    generate
        if (SUPPORT_2X_CLK) begin
            reg [18:0] cpu_address_r;
            reg cpu_mem_valid_r;
            reg [3:0] cpu_wstrb_r;

            always @(posedge clk) begin
                cpu_address_r <= cpu_address;
                cpu_mem_valid_r <= cpu_mem_valid;
                cpu_wstrb_r <= cpu_wstrb;
            end

            assign cpu_address_s = cpu_address_r;
            assign cpu_mem_valid_s = cpu_mem_valid_r;
            assign cpu_wstrb_s = cpu_wstrb_r;
        end else begin
            assign cpu_address_s = cpu_address;
            assign cpu_mem_valid_s = cpu_mem_valid;
            assign cpu_wstrb_s = cpu_wstrb;
        end
    endgenerate

    always @* begin
        cpu_ram_en = 0;
        flash_read_en = 0;
        status_en = 0;
        status_write_en = 0;
        vdp_en = 0;
        vdp_write_en = 0;
        dsp_en = 0;
        dsp_write_en = 0;

        if (cpu_mem_valid_s && !reset) begin
            case (cpu_address_s[18:16])
                0: cpu_ram_en = 1;
                1: vdp_en = 1;
                2: status_en = 1;
                3: dsp_en = 1;
                // (pad read...)
                // (BRAM / bootloader read...)
                4, 5, 6, 7: flash_read_en = 1;
            endcase

            vdp_write_en = vdp_en && cpu_wstrb_s;
            status_write_en = status_en && cpu_wstrb_s;
            dsp_write_en = dsp_en && cpu_wstrb_s;
        end
    end
 
endmodule

