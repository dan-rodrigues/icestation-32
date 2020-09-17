// "BUFFALO Classic USB Gamepad"

`default_nettype none

module usbh_report_decoder_buffalo(
    input  wire        i_clk,
    input  wire [63:0] i_report,
    input  wire        i_report_valid,
    output reg   [11:0] o_btn
);
    wire left = i_report[7:0] == 0;
    wire right = i_report[7:0] == 8'hff;
    wire up = i_report[15:8] == 0;
    wire down = i_report[15:8] == 8'hff;

    wire a = i_report[16];
    wire b = i_report[17];
    wire x = i_report[18];
    wire y = i_report[19];

    wire l = i_report[20];
    wire r = i_report[21];

    wire select = i_report[22];
    wire start = i_report[23];

    always @(posedge i_clk) begin
        if (i_report_valid) begin
            o_btn <= {
                r, l, x, a,
                right, left, down, up,
                start, select, y, b
            };
        end
    end

endmodule
