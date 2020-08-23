// ics32_top_ulx3s.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

`include "clocks.vh"

module ics32_top_ulx3s #(
    parameter [0:0] ENABLE_WIDESCREEN = 1,
    parameter [0:0] ENABLE_FAST_CPU = 0
) (
    input clk_25mhz,

    output [3:0] gpdi_dp,
    output [3:0] gpdi_dn,

    output [3:0] audio_l,
    output [3:0] audio_r,
    output [3:0] audio_v,

    output [7:0] led,

    input [6:0] btn,

    output flash_csn,
    inout [3:0] flash_io
);
    // --- Clocks ---

    localparam integer CLK_2X_FREQ = ENABLE_WIDESCREEN ? `CLK_2X_WIDESCREEN : `CLK_2X_STANDARD;
    localparam integer CLK_1X_FREQ = ENABLE_WIDESCREEN ? `CLK_1X_WIDESCREEN : `CLK_1X_STANDARD;

    // --- ECP5 PLL (640x480 or 848x480 clock selection) ---

    wire clk_1x, clk_2x, clk_10x;
    wire pll_locked;

    pll_ecp5 #(
        .ENABLE_FAST_CLK(ENABLE_WIDESCREEN)
    ) pll (
        .clk_25m(clk_25mhz),

        .locked(pll_locked),
        .clk_1x(clk_1x),
        .clk_2x(clk_2x),
        .clk_10x(clk_10x)
    );

    // --- HDMI ---

    hdmi_encoder hdmi(
        .pixel_clk(clk_2x),
        .pixel_clk_x5(clk_10x),

        .red({2{vga_r}}),
        .green({2{vga_g}}),
        .blue({2{vga_b}}),

        .vde(vga_de),
        .hsync(vga_hsync),
        .vsync(vga_vsync),

        .gpdi_dp(gpdi_dp),
        .gpdi_dn(gpdi_dn)
    );

    // --- DAC ---

    // SPDIF:

    wire [15:0] spdif_selected_sample = spdif_channel_select ? audio_output_r_valid : audio_output_l_valid;
    wire [23:0] spdif_pcm_in = {spdif_selected_sample, 8'b0};

    wire spdif;
    wire spdif_channel_select;
    assign audio_v = {2'b00, spdif, 1'b0};

    spdif_tx #(
      .C_clk_freq(CLK_2X_FREQ),
      .C_sample_freq(44100)
    ) spdif_tx (
      .clk(clk_2x),
      .data_in(spdif_pcm_in),
      .address_out(spdif_channel_select),
      .spdif_out(spdif)
    );

    // Analog:

    reg [15:0] audio_output_l_valid, audio_output_r_valid;

    always @(posedge clk_2x) begin
        if (audio_output_valid) begin
            audio_output_l_valid <= audio_output_l;
            audio_output_r_valid <= audio_output_r;
        end
    end

    dacpwm #(
        .C_pcm_bits(16),
        .C_dac_bits(4)
    ) dacpwm [1:0] (
        .clk(clk_2x),

        .pcm({audio_output_l_valid, audio_output_r_valid}),
        .dac({audio_l, audio_r})
    );

    // --- ECP5 Flash IO ---

    wire [3:0] flash_out;
    wire [3:0] flash_in_en;
    wire [3:0] flash_in;

    // Flash bidirectional IO

    wire [3:0] flash_out_r;
    wire [3:0] flash_in_en_r;
    wire [3:0] flash_in_r;

    (* BEL="X11/Y93/SLICEA" *) TRELLIS_SLICE flash_in_r_0 (
        .CLK(clk_2x),
        .M0(flash_in[0]), .M1(flash_in[1]),
        .Q0(flash_in_r[0]), .Q1(flash_in_r[1])
    );

    (* BEL="X11/Y93/SLICEB" *) TRELLIS_SLICE flash_in_r_1 (
        .CLK(clk_2x),
        .M0(flash_in[2]), .M1(flash_in[3]),
        .Q0(flash_in_r[2]), .Q1(flash_in_r[3])
    );

    (* BEL="X11/Y93/SLICEC" *) TRELLIS_SLICE flash_in_en_r_0 (
        .CLK(clk_2x),
        .M0(~flash_in_en[0]), .M1(~flash_in_en[1]),
        .Q0(flash_in_en_r[0]), .Q1(flash_in_en_r[1])
    );

    (* BEL="X11/Y93/SLICED" *) TRELLIS_SLICE flash_in_en_r_1 (
        .CLK(clk_2x),
        .M0(~flash_in_en[2]), .M1(~flash_in_en[3]),
        .Q0(flash_in_en_r[2]), .Q1(flash_in_en_r[3])
    );

    (* BEL="X9/Y93/SLICEA" *) TRELLIS_SLICE flash_out_r_0 (
        .CLK(clk_2x),
        .M0(flash_out[0]), .M1(flash_out[1]),
        .Q0(flash_out_r[0]), .Q1(flash_out_r[1]),
    );

    (* BEL="X9/Y93/SLICEB" *) TRELLIS_SLICE flash_out_r_1 (
        .CLK(clk_2x),
        .M0(flash_out[2]), .M1(flash_out[3]),
        .Q0(flash_out_r[2]), .Q1(flash_out_r[3]),
    );

    BB flash_io_bb[3:0] (
        .I(flash_in_r),
        .T(flash_in_en_r),
        .O(flash_out),
        .B(flash_io)
    );

    // Flash CSN

    wire flash_csn_r;

    (* BEL="X15/Y93/SLICEA" *) TRELLIS_SLICE flash_csn_r_0 (
        .CLK(clk_2x),
        .M0(flash_csn_io),
        .Q0(flash_csn_r)
    );

    OB flash_csn_ob(
        .I(flash_csn_r),
        .O(flash_csn)
    );

    // SPI CLK

    // * The ECP5 SPI clock must be controlled with USRMCLK
    // * DDR primitive can't be used with USRMCLK
    // * There is no built in supported to route a global clock USRMCLK

    wire [1:0] flash_clk_ddr_r;
    wire flash_clk_out = clk_2x ? flash_clk_ddr_r[0] : flash_clk_ddr_r[1];

    (* BEL="X2/Y93/SLICEA" *) TRELLIS_SLICE ddr_ff_0 (
        .CLK(clk_2x),
        .M0(flash_clk_ddr[0]),
        .Q0(flash_clk_ddr_r[0])
    );

    (* BEL="X2/Y92/SLICEA" *) TRELLIS_SLICE #(.CLKMUX("INV")) ddr_ff_1 (
        .CLK(clk_2x),
        .M0(flash_clk_ddr[1]),
        .Q0(flash_clk_ddr_r[1])
    );
    
    USRMCLK spi_clk (
        .USRMCLKI(flash_clk_out),
        .USRMCLKTS(1'b0)
    );

    // --- icestation-32 ---

    wire flash_csn_io;
    wire [1:0] flash_clk_ddr;

    wire [3:0] vga_r, vga_g, vga_b;
    wire vga_de, vga_vsync, vga_hsync;

    wire audio_output_valid;
    wire [15:0] audio_output_l, audio_output_r;

    ics32 #(
        .CLK_1X_FREQ(CLK_1X_FREQ),
        .CLK_2X_FREQ(CLK_2X_FREQ),
        .ENABLE_WIDESCREEN(ENABLE_WIDESCREEN),
        .ENABLE_FAST_CPU(ENABLE_FAST_CPU),
        .RESET_DURATION_EXPONENT(24),
        .ENABLE_BOOTLOADER(1)
    ) ics32 (
        .clk_1x(clk_1x),
        .clk_2x(clk_2x),
        .pll_locked(pll_locked),

        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),

        .vga_de(vga_de),
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),

        .btn_u(btn[3]),
        .btn_1(btn[4]),
        .btn_2(btn[5]),
        .btn_3(btn[6]),

        .led(led),

        .flash_clk_ddr(flash_clk_ddr),
        .flash_csn(flash_csn_io),
        .flash_in_en(flash_in_en),
        .flash_in(flash_in),
        .flash_out(flash_out_r),

        .audio_output_l(audio_output_l),
        .audio_output_r(audio_output_r),
        .audio_output_valid(audio_output_valid)
    );

endmodule
