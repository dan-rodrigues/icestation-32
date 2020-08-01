// This is based on the iCE40 SPRAM cell in the yosys techlibs

module spram_256k (
    input clk,
    input cs,
    input [13:0] address,
    input [15:0] write_data,
    input [3:0] mask,
    input write_en,
    output reg [15:0] read_data
);
    // This verilator comment is required for the C++ TB to do the IPL
    // It slows the sim down, revise this at some point

    reg [15:0] mem [0:16383] /* verilator public */ ;

    always @(posedge clk) begin
        if (cs) begin
            if (!write_en) begin
                read_data <= mem[address];
            end else begin
                if (mask[0]) mem[address][ 3: 0] <= write_data[ 3: 0];
                if (mask[1]) mem[address][ 7: 4] <= write_data[ 7: 4];
                if (mask[2]) mem[address][11: 8] <= write_data[11: 8];
                if (mask[3]) mem[address][15:12] <= write_data[15:12];
                read_data <= 0;
            end
        end
    end
    
endmodule
