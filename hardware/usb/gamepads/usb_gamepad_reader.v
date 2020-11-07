`default_nettype none

module usb_gamepad_reader #(
    parameter GAMEPAD = "BUFFALO"
) (
    input clk,
    input reset,

    input usb_dif,
    inout usb_dp,
    inout usb_dn,

    output [11:0] usb_btn
);
    localparam C_report_bytes = 8;
    
    wire [C_report_bytes*8-1:0] S_report;
    wire S_report_valid;
    wire [7:0] usb_buttons;

    usbh_host_hid #(
        .C_usb_speed(0),
        .C_report_length(C_report_bytes),
        .C_report_length_strict(0)
    ) us2_hid_host (
        .clk(clk),
        .bus_reset(reset),
        .usb_dif(usb_dif),
        .usb_dp(usb_dp),
        .usb_dn(usb_dn),
        .hid_report(S_report),
        .hid_valid(S_report_valid)
    );

    generate
        if (GAMEPAD == "BUFFALO") begin
            usbh_report_decoder_buffalo usbh_report_decoder(
                .i_clk(clk),
                .i_report(S_report),
                .i_report_valid(S_report_valid),
                .o_btn(usb_btn)
            );
        end

        if (GAMEPAD == "KEYPAD") begin
            usbh_report_decoder_keypad usbh_report_decoder(
                .i_clk(clk),
                .i_report(S_report),
                .i_report_valid(S_report_valid),
                .o_btn(usb_btn)
            );
        end

        if (GAMEPAD == "WINGMAN") begin
            usbh_report_decoder_wingman usbh_report_decoder(
                .i_clk(clk),
                .i_report(S_report),
                .i_report_valid(S_report_valid),
                .o_btn(usb_btn)
            );
        end

        // (...more gamepads)

    endgenerate

endmodule
