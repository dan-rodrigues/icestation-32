`default_nettype none

module vdp_map_address_generator(
    input [9:0] scroll_y,
    input [6:0] scroll_x_coarse,

    input [9:0] raster_y,
    input [6:0] raster_x_coarse,

    input [13:0] map_base_address,
    input [7:0] stride,

    output [13:0] map_address
);

    wire [6:0] column = scroll_x_coarse + raster_x_coarse;
    wire [5:0] row = (scroll_y + raster_y) >> 3;

    // cheap, only requires +1 LUT
    wire map_page_select = (stride & 8'h80) && column[6];

    always @* begin
        map_address = {map_page_select, row, column[5:0]} + map_base_address;
    end

    // Most of these are probably the "+ map_base_address" which gets optimised when 64 or 128 is used
    // Number of cells:                 54
    //   SB_CARRY                       27
    //   SB_LUT4                        27

    // ---

    // equivalent to this but limited to the 2 current use cases:
    // assign map_address =  map_base_address + column + row * stride;

    // SB_MAC16 cell used when running yosys + -noflatten
    // with flattening it optimises as expected

    // ---

    // this is the nicer alternative but expensive
    // not as nice of an API though

    // always @* begin
    //  if (stride & 8'h80) begin
    //      //breaks, as expected
    //      map_address = {row, column} + map_base_address;
    //  end else begin
    //      // works, as before
    //      map_address = {row, column[5:0]} + map_base_address;
    //  end
    // end

     //   Number of cells:                 90
     //     SB_CARRY                       40
     //     SB_LUT4                        50

endmodule
