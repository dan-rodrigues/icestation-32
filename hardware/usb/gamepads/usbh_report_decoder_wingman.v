// 046d:c20a Logitech, Inc. WingMan RumblePad

`default_nettype none

module usbh_report_decoder_wingman(
    input  wire        i_clk,
    input  wire [63:0] i_report,
    input  wire        i_report_valid,
    output reg   [11:0] o_btn
);
// HID report layout:
//
//  [7:0]   Left stick X
//  [15:8]  Left stick Y
//  [23:16] Throttle slider
//  [31:24] Right stick X
//  [39:32] Right stick Y
//  [43:40] Hat (clockwise)
//  [44]    Button A
//  [45]    Button B
//  [46]    Button C
//  [47]    Button X
//  [48]    Button Y
//  [49]    Button Z
//  [50]    Button L
//  [51]    Button R
//  [52]    Button S
//  [53]    Application 1
//  [54]    Application 2
//  [55]    Application 3: Rumble
//  [56]    Application 4: Mode
//  [57]    Application 5
//  [58]    Application 6
//  [59]    Application 7
//  [60]    Application 8
//  [61]    Application 9
//  [62]    Application 10
//  [63]    Application 11
//
// Hat switch values:
//
//                     LRUD
//    0 = up           0010
//    1 = right-up     0110
//    2 = right        0100
//    3 = right-down   0101
//    4 = down         0001
//    5 = left-down    1001
//    6 = left         1000
//    7 = left-up      1010
//    8 = unpressed    0000
//
// Layout (Logitech):
//
//          Z
//    Y
//            C
// X     B
//
//    A
//
// Layout (SNES):
//
//                  X   A
//
// Select  Start  Y   B
//
// Mapping:
//
//   LEFT/RIGHT/UP/DOWN = Hat, ignore analog sticks for now
//   A = B
//   B = A
//   X = Y
//   Y = X
//   L = L
//   R = R
//   Select = C
//   Start = S
//
    wire [3:0] hat = i_report[43:40];
    wire left = hat == 5 | hat == 6 | hat == 7;
    wire right = hat == 1 | hat == 2 | hat == 3;
    wire up = hat == 0 | hat == 1 | hat == 7;
    wire down = hat == 3 | hat == 4 | hat == 5;

    wire a = i_report[45];
    wire b = i_report[44];
    wire x = i_report[48];
    wire y = i_report[47];

    wire l = i_report[50];
    wire r = i_report[51];

    wire select = i_report[46];
    wire start = i_report[52];

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
