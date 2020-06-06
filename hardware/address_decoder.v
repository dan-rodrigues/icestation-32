// address_decoder.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

`include "debug.vh"

module address_decoder #(
    parameter REGISTERED_INPUTS = 0
) (
    input clk,
    input reset,

    input [19:0] cpu_address,
    input cpu_mem_valid,
    input [3:0] cpu_wstrb,

    output reg bootloader_en,

    output reg vdp_en,
    output reg vdp_write_en,

    output reg cpu_ram_en,
    output reg cpu_ram_write_en,

    output reg status_en,
    output reg status_write_en,

    output reg flash_read_en,

    output reg dsp_en,
    output reg dsp_write_en,

    output reg pad_en,
    output reg pad_write_en,

    output reg cop_ram_write_en
);
    wire [19:0] cpu_address_s;
    wire cpu_mem_valid_s;
    wire [3:0] cpu_wstrb_s;

    generate
        if (REGISTERED_INPUTS) begin
            reg [19:0] cpu_address_r;
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

    // this doesn't need to be exposed but is here for consistency
    reg cop_ram_en;

    always @* begin
        bootloader_en = 0;
        cpu_ram_en = 0;
        cpu_ram_write_en = 0;
        flash_read_en = 0;
        status_en = 0;
        status_write_en = 0;
        vdp_en = 0;
        vdp_write_en = 0;
        dsp_en = 0;
        dsp_write_en = 0;
        pad_en = 0;
        pad_write_en = 0;
        cop_ram_en = 0;
        cop_ram_write_en = 0;

        if (cpu_mem_valid_s && !reset) begin
            if (cpu_address_s[19]) begin
                flash_read_en = 1;
            end else begin
                case (cpu_address_s[18:16])
                    0: cpu_ram_en = 1;
                    1: vdp_en = 1;
                    2: status_en = 1;
                    3: dsp_en = 1;
                    4: pad_en = 1;
                    5: cop_ram_en = 1;
                    6: bootloader_en = 1;
                    7: begin
                        `stop($display("unexepcted address: %x", cpu_address_s))
                    end
                endcase    
            end

            cpu_ram_write_en = cpu_ram_en && cpu_wstrb_s;
            vdp_write_en = vdp_en && cpu_wstrb_s;
            status_write_en = status_en && cpu_wstrb_s;
            dsp_write_en = dsp_en && cpu_wstrb_s;
            pad_write_en = pad_en && cpu_wstrb_s;
            cop_ram_write_en = cop_ram_en && cpu_wstrb_s;
        end
    end
 
endmodule

