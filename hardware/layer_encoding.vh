`ifndef layer_encoding_vh
`define layer_encoding_vh

localparam LAYER_SPRITES = 4;
localparam LAYER_SCROLL3 = 3;
localparam LAYER_SCROLL2 = 2;
localparam LAYER_SCROLL1 = 1;
localparam LAYER_SCROLL0 = 0;

// yosys segfaults if the above localparams are used in place of the shift count below
// Yosys 0.9+2406 (git sha1 b350398c, clang 11.0.0 -fPIC -Os)

localparam LAYER_SPRITES_OHE = (1 << 4);
localparam LAYER_SCROLL3_OHE = (1 << 3);
localparam LAYER_SCROLL2_OHE = (1 << 2);
localparam LAYER_SCROLL1_OHE = (1 << 1);
localparam LAYER_SCROLL0_OHE = (1 << 0);

`endif
