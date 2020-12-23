// ulx3s_gamepad_state.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module ulx3s_gamepad_state #(
    // Set to one of "PCB", "USB" or "BLUETOOTH"
    parameter GAMEPAD_SOURCE = "PCB",
    parameter USB_GAMEPAD = "BUFFALO"
) (
    input clk,
    input reset,

    // ESP32:

    output esp32_en,
    output esp32_gpio0,
    output esp32_gpio12,

    input esp32_gpio2,
    input esp32_gpio16,
    input esp32_gpio4,

    // USB:

    input clk_usb,
    input usb_reset,

    input usb_dif,
    inout usb_dp,
    inout usb_dn,

    output usb_pu_dp,
    output usb_pu_dn,

    // PCB:

    input [6:0] btn,

    // Selected gamepad state:

    output [11:0] pad_btn
);
    generate
        if (GAMEPAD_SOURCE == "BLUETOOTH") begin
            // ESP32 + Bluetooth gamepads

            // Inputs:

            reg [2:0] esp_sync_ff [0:1];

            wire esp_spi_mosi = esp_sync_ff[1][2];
            wire esp_spi_clk = esp_sync_ff[1][1];
            wire esp_spi_csn = esp_sync_ff[1][0];

            always @(posedge clk) begin
                esp_sync_ff[1] <= esp_sync_ff[0];
                esp_sync_ff[0] <= {esp32_gpio4, esp32_gpio16, esp32_gpio2};
            end

            // Debouncer (only needed for ESP32 reset):

            wire esp32_reset;

            debouncer #(
                .BTN_COUNT(1)
            ) esp32_reset_debouncer (
                .clk(clk),
                .reset(reset),

                .btn(!btn[0]),
                .level(esp32_reset)
            );

            // SPI gamepad reader:

            esp32_spi_gamepad esp32_spi_gamepad(
                .clk(clk),
                .reset(reset),

                .user_reset(esp32_reset),
                .esp32_en(esp32_en),
                .esp32_gpio0(esp32_gpio0),
                .esp32_gpio12(esp32_gpio12),

                .spi_csn(esp_spi_csn),
                .spi_clk(esp_spi_clk),
                .spi_mosi(esp_spi_mosi),

                .pad_btn(pad_btn)
            );
        end else begin
            // Keep ESP32 enabled for programming through WiFi:

            assign esp32_en = 1;
            assign esp32_gpio0 = 1;

            if (GAMEPAD_SOURCE == "USB") begin
                // USB gamepad (US2):

                assign usb_pu_dp = 1'b0;
                assign usb_pu_dn = 1'b0;

                wire [11:0] usb_btn;

                usb_gamepad_reader #(
                    .GAMEPAD(USB_GAMEPAD)
                ) usb_gamepad_reader (
                    .clk(clk_usb),
                    .reset(usb_reset),

                    .usb_dif(usb_dif),
                    .usb_dp(usb_dp),
                    .usb_dn(usb_dn),

                    .usb_btn(usb_btn)
                );

                reg [11:0] buttons_sync_ff [0:1];
                assign pad_btn = buttons_sync_ff[1];

                always @(posedge clk) begin
                    buttons_sync_ff[1] <= buttons_sync_ff[0];
                    buttons_sync_ff[0] <= usb_btn;
                end
            end else if (GAMEPAD_SOURCE == "PCB") begin
                // PCB buttons:

                assign pad_btn = {btn[6], btn[5], btn[4], btn[3], 1'b0, !btn[0], btn[1], btn[2]};
            end else begin
                // GAMEPAD_SOURCE not set correctly so error out.
                // Doesn't seem to be a nicer way to do this in Verilog-2005
                non_existant_module GAMEPAD_SOURCE_INVALID_PARAMETER();
            end
        end
    endgenerate

endmodule
