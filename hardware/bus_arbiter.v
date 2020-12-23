// bus_arbiter.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

`include "bus_arbiter.vh"

module bus_arbiter #(
    parameter SUPPORT_2X_CLK = 0,
    parameter DEFAULT_CPU_RAM_READ = 0,
    parameter READ_SOURCES = `BA_ALL
) (
    input clk,

    // CPU inputs

    input [3:0] cpu_wstrb,
    input [15:0] cpu_address,
    input [31:0] cpu_write_data,

    // Address decoder inputs

    input bootloader_en,
    input vdp_en,
    input flash_read_en,
    input cpu_ram_en,
    input dsp_en,
    input status_en,
    input pad_en,
    input cop_en,
    input flash_ctrl_en,
    input audio_ctrl_en,

    // Ready-inputs from peripherals

    input flash_read_ready,
    input vdp_ready,
    input audio_ready,

    // Data inputs from peripherals

    input [31:0] bootloader_read_data,
    input [31:0] cpu_ram_read_data,
    input [31:0] flash_read_data,
    input [15:0] vdp_read_data,
    input [31:0] dsp_read_data,
    input [2:0] pad_read_data,
    input [3:0] flash_ctrl_read_data,
    input [7:0] audio_cpu_read_data,

    // CPU outputs

    output reg cpu_mem_ready,
    output [31:0] cpu_read_data
);
    wire cpu_ram_ready, peripheral_ready;
    
    wire any_peripheral_ready = ((vdp_en && vdp_ready)
        || flash_ctrl_en || status_en || dsp_en || pad_en
        || cop_en || bootloader_en || audio_ready);

    generate
        // using !cpu_mem_ready only works in CPU clk is full speed
        if (!SUPPORT_2X_CLK) begin
            assign cpu_ram_ready = cpu_ram_en && !cpu_mem_ready;
            assign peripheral_ready = any_peripheral_ready && !cpu_mem_ready;
        end else begin
            assign cpu_ram_ready = cpu_ram_en;
            assign peripheral_ready = any_peripheral_ready;
        end
    endgenerate

    always @(posedge clk) begin
        cpu_mem_ready <= cpu_ram_ready || flash_read_ready || peripheral_ready;
    end

    // needs registering due to timing
    reg flash_read_en_r;

    always @(posedge clk) begin
        flash_read_en_r <= flash_read_en;
    end

    reg [31:0] cpu_read_data_ps, cpu_read_data_s;
    assign cpu_read_data = cpu_read_data_s;

    always @* begin
        if (READ_SOURCES & `BA_CPU_RAM) begin
            cpu_read_data_ps = cpu_ram_read_data;
        end else if (READ_SOURCES & `BA_FLASH) begin
            cpu_read_data_ps = flash_read_data;
        end else begin
            cpu_read_data_ps = {32{1'bx}};
        end

        // the && with the parameters looks strange here but without it, it doesn't get optimized
        // providing constants for the *_en inputs does not optimize as desired
        // doing the && at the parameter level does work as expected though and reduces *flattened* cell count

        if (flash_read_en_r && (READ_SOURCES & `BA_FLASH)) begin
            cpu_read_data_ps = flash_read_data;
        end else if (vdp_en && (READ_SOURCES & `BA_VDP)) begin
            cpu_read_data_ps[15:0] = vdp_read_data;
        end else if (dsp_en && (READ_SOURCES & `BA_DSP)) begin
            cpu_read_data_ps = dsp_read_data;
        end else if (pad_en && (READ_SOURCES & `BA_PAD)) begin
            cpu_read_data_ps[2:0] = pad_read_data;
        end else if (bootloader_en && (READ_SOURCES & `BA_BOOT)) begin
            cpu_read_data_ps = bootloader_read_data;
        end else if (cpu_ram_en && (READ_SOURCES & `BA_CPU_RAM)) begin
            cpu_read_data_ps = cpu_ram_read_data;
        end else if (flash_ctrl_en && (READ_SOURCES & `BA_FLASH_CTRL)) begin
            cpu_read_data_ps[3:0] = flash_ctrl_read_data;
        end else if (audio_ctrl_en && (READ_SOURCES & `BA_AUDIO)) begin
            cpu_read_data_ps[7:0] = audio_cpu_read_data;
        end
    end

    generate
        if (SUPPORT_2X_CLK) begin
            reg [31:0] cpu_read_data_r;

            always @* begin
                cpu_read_data_s = cpu_read_data_r;
            end

            always @(posedge clk) begin
                cpu_read_data_r <= cpu_read_data_ps;
            end
        end else begin
            always @* begin
                cpu_read_data_s = cpu_read_data_ps;
            end
        end
    endgenerate

endmodule
