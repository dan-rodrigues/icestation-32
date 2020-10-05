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

    input [24:0] cpu_address,
    input cpu_mem_valid,
    input [3:0] cpu_wstrb,
    output reg [3:0] cpu_wstrb_decoder,

    output reg bootloader_en,

    output reg vdp_en,
    output reg vdp_write_en,

    output reg audio_ctrl_en,
    output reg audio_ctrl_write_en,

    output reg cpu_ram_en,
    output reg cpu_ram_write_en,

    output reg status_en,
    output reg status_write_en,

    output reg flash_read_en,

    output reg dsp_en,
    output reg dsp_write_en,

    output reg pad_en,
    output reg pad_write_en,

    output reg cop_ram_write_en,

    output reg flash_ctrl_en,
    output reg flash_ctrl_write_en
);
    reg [24:0] cpu_address_r;
    reg cpu_mem_valid_r;

    generate
        if (REGISTERED_INPUTS) begin
            always @(posedge clk) begin
                cpu_address_r <= cpu_address;
                cpu_mem_valid_r <= cpu_mem_valid;
                cpu_wstrb_decoder <= cpu_wstrb;
            end
        end else begin
            always @* begin
                cpu_address_r = cpu_address;
                cpu_mem_valid_r = cpu_mem_valid;
                cpu_wstrb_decoder = cpu_wstrb;
            end
        end
    endgenerate

    // this doesn't need to be exposed but is here for consistency
    reg cop_ram_en;

    always @* begin
        bootloader_en = 0;
        flash_read_en = 0;
        audio_ctrl_en = 0; audio_ctrl_write_en = 0;
        cpu_ram_en = 0; cpu_ram_write_en = 0;
        status_en = 0; status_write_en = 0;
        vdp_en = 0; vdp_write_en = 0;
        dsp_en = 0; dsp_write_en = 0;
        pad_en = 0; pad_write_en = 0;
        cop_ram_en = 0; cop_ram_write_en = 0;
        flash_ctrl_en = 0; flash_ctrl_write_en = 0;

        if (cpu_mem_valid_r && !reset) begin
            if (cpu_address_r[24]) begin
                flash_read_en = 1;
            end else begin
                case (cpu_address_r[19:16])
                    0: cpu_ram_en = 1;
                    1: vdp_en = 1;
                    2: status_en = 1;
                    3: dsp_en = 1;
                    4: pad_en = 1;
                    5: cop_ram_en = 1;
                    6: bootloader_en = 1;
                    7: flash_ctrl_en = 1;
                    8: audio_ctrl_en = 1;
                endcase    
            end

            cpu_ram_write_en = cpu_ram_en && cpu_wstrb_decoder;
            vdp_write_en = vdp_en && cpu_wstrb_decoder;
            status_write_en = status_en && cpu_wstrb_decoder;
            dsp_write_en = dsp_en && cpu_wstrb_decoder;
            pad_write_en = pad_en && cpu_wstrb_decoder;
            cop_ram_write_en = cop_ram_en && cpu_wstrb_decoder;
            flash_ctrl_write_en = flash_ctrl_en && cpu_wstrb_decoder;
            audio_ctrl_write_en = audio_ctrl_en && cpu_wstrb_decoder;
        end
    end
 
endmodule

