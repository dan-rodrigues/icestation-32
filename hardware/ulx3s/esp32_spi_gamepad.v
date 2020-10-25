// esp32_spi_gamepad.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module esp32_spi_gamepad #(
    parameter integer PAD_BUTTONS = 12
) (
    input clk,
    input reset,

    // ESP32 reset support

    input user_reset,
    output esp32_en,
    output esp32_gpio0,
    output esp32_gpio12,

    // SPI gamepad input

    input spi_csn,
    input spi_clk,
    input spi_mosi,

    output reg [PAD_BUTTONS - 1:0] pad_btn
);
    localparam PAD_WIDTH = PAD_BUTTONS - 1;

    // --- ESP32 resetting ---

    assign esp32_en = !user_reset;

    // ESP32 "strapping pins" for boot:
    // MTDI (GPIO12) apparently has pull down in ESP32 but still need this for whatever reason
    // Serial console shows ESP32 stuck in reset loop otherwise

    // GPIO0 = 1 (SPI flash boot, instead of serial bootloader)
    assign esp32_gpio0 = 1;

    // MTDI = 0 (VDD_SDIO = 3.3v, instead of 1.8v)
    assign esp32_gpio12 = 0;

    // --- SPI gamepad ---

    reg spi_clk_r;
    reg spi_csn_r;

    reg [PAD_WIDTH:0] receive_buffer;

    wire spi_csn_rose = spi_csn && !spi_csn_r;
    wire spi_csn_fell = !spi_csn && spi_csn_r;
    wire spi_clk_rose = spi_clk && !spi_clk_r;

    always @(posedge clk) begin
        if (reset) begin
            pad_btn <= 0;
            spi_clk_r <= 0;
            spi_csn_r <= 1;
        end else begin
            spi_clk_r <= spi_clk;
            spi_csn_r <= spi_csn;

            if (!spi_csn && spi_clk_rose) begin
                receive_buffer <= {spi_mosi, receive_buffer[PAD_WIDTH:1]};
            end else if (spi_csn_rose) begin
                pad_btn <= receive_buffer;
            end
        end
    end

endmodule
