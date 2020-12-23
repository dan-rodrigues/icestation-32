// ics32_tb.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module ics32_tb(
    input clk_1x,
    input clk_2x,

    output [3:0] vga_r,
    output [3:0] vga_g,
    output [3:0] vga_b,

    output vga_hsync,
    output vga_vsync,
    output vga_de,

    output [7:0] led,

    input btn_u,
    input btn_1,
    input btn_2,
    input btn_3,

    input btn_down,
    input btn_up,

    input btn_l,
    input btn_r,

    input btn_y,
    input btn_x,
    input btn_a,

    input btn_select,
    input btn_start
);
    ics32 #(
        .CLK_1X_FREQ(`CLK_1X_WIDESCREEN),
        .CLK_2X_FREQ(`CLK_2X_WIDESCREEN),
        .ENABLE_WIDESCREEN(1),
        .ENABLE_FAST_CPU(0),
        .RESET_DURATION_EXPONENT(2),
        .ADPCM_STEP_LUT_PATH("../hardware/adpcm_step_lut.hex"),
        .BOOTLOADER_SIZE(512),

        // Vex is smaller but for simulation the Pico is faster (fully synchronous)
        .USE_VEXRISCV(1),

        // The boot code configures the QSPI flash which is needed to access any flash resources such as audio
        // If this isn't needed, this can be disabled to speed up the sim start time
        .ENABLE_BOOTLOADER(1)
    ) ics32 (
        .clk_1x(clk_1x),
        .clk_2x(clk_2x),
        .reset_1x(),
        .reset_2x(),
        .pll_locked(1),

        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),

        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),
        .vga_de(vga_de),

        .pad_latch(pad_latch),
        .pad_clk(pad_clk),
        .pad_data(pad_read_data),

        .user_button(btn_u),
        
        .led(led),

        .flash_clk_ddr(flash_clk_ddr),
        .flash_csn(flash_csn),
        .flash_in_en(flash_in_en),
        .flash_in(flash_in),
        .flash_out(flash_out),

        .audio_output_valid(audio_valid),
        .audio_output_l(audio_l),
        .audio_output_r(audio_r)
    );

    // --- Gamepad reading ---

    // Only the 3 buttons on the breakboard are used as a partial gamepad
    // This can be extended later with an actual gamepad PMOD

    wire [11:0] pad_btn = {
        btn_r, btn_l, btn_x, btn_a,
        btn_1, btn_3, btn_down, btn_up,
        btn_start, btn_select, btn_y, btn_2
    };

    wire [1:0] pad_read_data;

    wire pad_latch, pad_clk;

    // P1 is currently controllable in the sim

    mock_gamepad mock_gamepad(
        .clk(clk_2x),

        .pad_clk(pad_clk),
        .pad_btn(pad_btn),
        .pad_latch(pad_latch),

        .pad_out(pad_read_data[0])
    );

    // P2 isn't

    assign pad_read_data[1] = 0;


    // --- Flash sim blackbox ---

    wire [1:0] flash_clk_ddr;
    wire flash_csn;
    wire [3:0] flash_in_en;
    wire [3:0] flash_in;
    wire [3:0] flash_out;

    reg [3:0] flash_in_r;
    reg [3:0] flash_out_r;
    reg flash_csn_r;

    assign flash_csn_bb = flash_csn_r;
    assign flash_in_bb = flash_in_r;
    assign flash_in_en_bb = flash_in_en;
    wire [3:0] flash_out = flash_out_r;
    
    always @(posedge clk_2x) begin
        flash_in_r <= flash_in;
        flash_csn_r <= flash_csn;

        flash_out_r <= flash_out_bb;
    end

    // This isn't quite what SB_IO does in DDR mode
    // Since we're not actually pushing out DDR data streams, this could be replaced with a reimplementation of flash_clk_out
    // There might be also a simpler way to do this in a way that works in both sims

    reg flash_clk_l, flash_clk_h;
    assign flash_clk_bb = clk_2x ? flash_clk_h : flash_clk_l;

    always @(posedge clk_2x) begin
        flash_clk_h <= flash_clk_ddr[0];
    end

    always @(negedge clk_2x) begin
        flash_clk_l <= flash_clk_ddr[1];
    end

    // Parameters could be forwarded to the sim factory functions
    // This could later be used to assume a certain power-up state (depending on icepack "-s" switch)

    wire flash_clk_bb;
    wire flash_csn_bb;
    wire [3:0] flash_in_bb;
    wire [3:0] flash_in_en_bb;
    wire [3:0] flash_out_bb;

    flash_bb flash(
        .clk(flash_clk_bb),
        .csn(flash_csn_bb),
        .in_en(flash_in_en_bb),
        .in(flash_in_bb),
        .out(flash_out_bb),
        .out_en()
    );

    // --- Audio DAC blackbox ---

    wire audio_valid;
    wire [15:0] audio_l, audio_r;

    audio_dac_bb audio(
        .clk(clk_2x),
        .valid(audio_valid),
        .in_l(audio_l),
        .in_r(audio_r)
    );

endmodule

(* cxxrtl_blackbox *)
module flash_bb(
    input clk /* verilator public */,
    input csn /* verilator public */,
    input [3:0] in_en /* verilator public */,
    input [3:0] in /* verilator public */,
    (* cxxrtl_sync *) output [3:0] out /* verilator public */,
    (* cxxrtl_sync *) output [3:0] out_en /* verilator public */
);

/* verilator public_module */

endmodule

(* cxxrtl_blackbox *)
module audio_dac_bb(
    (* cxxrtl_edge = "p" *) input clk /* verilator public */,
    input valid /* verilator public */,
    input [15:0] in_l /* verilator public */,
    input [15:0] in_r /* verilator public */
);

/* verilator public_module */

endmodule
