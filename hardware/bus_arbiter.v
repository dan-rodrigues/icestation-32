// bus_arbiter.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module bus_arbiter #(
    parameter SUPPORT_2X_CLK = 0,
    parameter DEFAULT_CPU_RAM_READ = 0
) (
    input clk,

    // CPU inputs
    input [3:0] cpu_wstrb,
    input [15:0] cpu_address,
    input [31:0] cpu_write_data,

    // address decoder inputs
    input bootloader_en,
    input vdp_en,
    input flash_read_en,
    input cpu_ram_en,
    input dsp_en,
    input status_en,
    input pad_en,
    input cop_en,

    // ready inputs from read sources
    input flash_read_ready,
    input vdp_ready,

    // data inputs from read sources
    input [31:0] bootloader_read_data,
    input [31:0] cpu_ram_read_data,
    input [31:0] flash_read_data,
    input [15:0] vdp_read_data,
    input [31:0] dsp_read_data,
    input [1:0] pad_read_data,

    // CPU outputs
    output reg cpu_mem_ready,
    output [31:0] cpu_read_data
);
    wire cpu_ram_ready, peripheral_ready;
    
    generate
        // using !cpu_mem_ready only works if the CPU clk is full speed
        // (refactor this that cpu_mem_ready check is the only point of difference)
        if (!SUPPORT_2X_CLK) begin
            assign cpu_ram_ready = cpu_ram_en && !cpu_mem_ready;
            assign peripheral_ready = ((vdp_en && vdp_ready) || status_en || dsp_en || pad_en || cop_en || bootloader_en) && !cpu_mem_ready;
        end else begin
            assign cpu_ram_ready = cpu_ram_en;
            assign peripheral_ready = ((vdp_en && vdp_ready) || status_en || dsp_en || pad_en || cop_en || bootloader_en);
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
        if (DEFAULT_CPU_RAM_READ) begin
            cpu_read_data_ps = cpu_ram_read_data;
        end else begin
            cpu_read_data_ps = flash_read_data;
        end

        // ...
        
        if (flash_read_en_r) begin
            cpu_read_data_ps = flash_read_data;
        end else if (vdp_en) begin
            cpu_read_data_ps[15:0] = vdp_read_data;
        end else if (dsp_en) begin
            cpu_read_data_ps = dsp_read_data;
        end else if (pad_en) begin
            cpu_read_data_ps[1:0] = pad_read_data;
        end else if (bootloader_en) begin
            cpu_read_data_ps = bootloader_read_data;
        end else if (cpu_ram_en) begin
            cpu_read_data_ps = cpu_ram_read_data;
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

/*
=== $paramod\bus_arbiter\SUPPORT_2X_CLK=0 ===

   Number of wires:                111
   Number of wire bits:            393
   Number of public wires:         111
   Number of public wire bits:     393
   Number of memories:               0
   Number of memory bits:            0
   Number of processes:              0
   Number of cells:                120
     SB_DFF                          2
     SB_LUT4                       118

=== $paramod\bus_arbiter\SUPPORT_2X_CLK=1'1 ===

   Number of wires:                113
   Number of wire bits:            426
   Number of public wires:         113
   Number of public wire bits:     426
   Number of memories:               0
   Number of memory bits:            0
   Number of processes:              0
   Number of cells:                152
     SB_DFF                         34
     SB_LUT4                       118

     vs.

=== $paramod\bus_arbiter\SUPPORT_2X_CLK=0 ===

   Number of wires:                 27
   Number of wire bits:            309
   Number of public wires:          27
   Number of public wire bits:     309
   Number of memories:               0
   Number of memory bits:            0
   Number of processes:              0
   Number of cells:                 36
     SB_DFF                          1
     SB_LUT4                        35

=== $paramod\bus_arbiter\SUPPORT_2X_CLK=1'1 ===

   Number of wires:                 64
   Number of wire bits:            377
   Number of public wires:          64
   Number of public wire bits:     377
   Number of memories:               0
   Number of memory bits:            0
   Number of processes:              0
   Number of cells:                103
     SB_DFF                         34
     SB_LUT4                        69


     */
