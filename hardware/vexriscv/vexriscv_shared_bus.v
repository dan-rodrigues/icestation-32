// vexriscv_shared_bus.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

// This is a basic wrapper module that adapts the Vex split ibus / dbus to a shared bus.
// The interface follows the naming of the PicoRV32 assumed by the rest of the system.

// Not ideal for performance since ibus / dbus can run concurrently depending on addresses.
// It does work without modifying the rest of system and can be used to easily switch between Pico/Vex.

// VexRiscV project, which was used to generate the two sources included in the vexriscv/ directory: 
// https://github.com/SpinalHDL/VexRiscv

`default_nettype none

module vexriscv_shared_bus(
    input clk,
    input reset,

    input mem_ready,
    output mem_valid,

    output [31:0] mem_addr,
    input [31:0] mem_rdata,
    output [31:0] mem_wdata,
    output [3:0] mem_wstrb
);
    // PicoRV32-style bus interface

    assign mem_addr = vex_address_r;
    assign mem_wdata = vex_data_r;
    assign mem_wstrb = vex_wstrb;

    assign mem_valid = vex_bus_active;

    // VexRiscV simple ibus / dbus <-> PicoRV32 bus adapter

    reg vex_bus_active;

    reg vex_i_bus_active;
    wire vex_d_bus_active = !vex_i_bus_active;

    reg [31:0] vex_address_r;
    reg [31:0] vex_data_r;
    reg [3:0] vex_wstrb;

    wire vex_mem_ready = vex_bus_active && mem_ready;
    wire vex_i_rsp_valid = vex_i_bus_active && vex_mem_ready;
    wire vex_d_rsp_valid = vex_d_bus_active && vex_mem_ready;

    wire [1:0] vex_write_size;
    wire vex_d_write_en;
    wire [31:0] vex_d_write_data;

    wire vex_i_valid, vex_d_valid;
    wire [31:0] vex_i_address;
    wire [31:0] vex_d_address;

    // iBus_cmd_ready can be driven using comb. logic with iBus_cmd_valid..
    wire vex_i_ready = vex_i_valid && !vex_bus_active;
    // ..but dBus_cmd_ready can't usse iBus_cmd_valid without logic loops, so register it
    reg vex_d_started;
    wire vex_d_ready = vex_d_started && vex_d_valid && vex_bus_active;

    always @(posedge clk) begin
        if (reset) begin
            vex_bus_active <= 0;
            vex_d_started <= 0;
        end else begin
            vex_d_started <= 0;

            if (!vex_bus_active) begin
                if (vex_i_valid) begin
                    vex_i_bus_active <= 1;
                    vex_bus_active <= 1;

                    vex_address_r <= vex_i_address;
                end else if (vex_d_valid) begin
                    vex_i_bus_active <= 0;
                    vex_bus_active <= 1;
                    vex_d_started <= 1;

                    vex_address_r <= vex_d_address;
                    vex_data_r <= vex_d_write_data;
                    vex_wstrb <= vex_d_write_en ? (((1 << (1 << vex_write_size)) - 1) << vex_d_address[1:0]) : 0;
                end
            end else if (vex_mem_ready) begin
                vex_bus_active <= 0;
                vex_wstrb <= 0;
                vex_d_started <= 0;
            end
        end
    end

    VexRiscv vex(
        .clk(clk),
        .reset(reset),

        .iBus_cmd_payload_pc(vex_i_address),
        .iBus_cmd_valid(vex_i_valid),
        .iBus_cmd_ready(vex_i_ready),

        .iBus_rsp_payload_inst(mem_rdata),
        .iBus_rsp_valid(vex_i_rsp_valid),

        .dBus_cmd_payload_address(vex_d_address),
        .dBus_cmd_payload_data(vex_d_write_data),
        .dBus_cmd_payload_size(vex_write_size),
        .dBus_cmd_payload_wr(vex_d_write_en),
        .dBus_cmd_valid(vex_d_valid),
        .dBus_cmd_ready(vex_d_ready),

        .dBus_rsp_ready(vex_d_rsp_valid),
        .dBus_rsp_data(mem_rdata),

        .dBus_rsp_error(0),
        .iBus_rsp_payload_error(0)
    );

endmodule
