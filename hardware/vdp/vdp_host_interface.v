`default_nettype none

module vdp_host_interface #(
    parameter USE_8BIT_BUS = 0
) (
    input clk,
    input reset,

    input [6:0] address_in,
    output reg [5:0] address_out,

    // writes

    input write_en_in,
    input [15:0] data_in,
    output reg write_en_out,
    output reg [15:0] data_out,

    // reads

    // must delay the CPU by atleast 1 cycle because this is all pipelined

    input read_en_in,
    output reg ready
);
    reg write_en_in_r, write_en_in_d;
    reg read_en_in_r, read_en_in_d;

    // only used in 8bit mode
    reg [7:0] data_in_r;
    reg [6:0] address_in_r;
    
    always @(posedge clk) begin
        address_in_r <= address_in;
        data_in_r <= data_in;

        write_en_in_r <= write_en_in;
        write_en_in_d <= write_en_in_r;

        read_en_in_r <= read_en_in;
        read_en_in_d <= read_en_in_r;
    end

    // this is intended to stall by some variable number of cycles, when that's inevitably needed
    
    reg [1:0] busy_counter;
    reg busy;

    always @(posedge clk) begin
        if (reset) begin
            busy_counter <= 0;
            busy <= 0;
            ready <= 0;
        end else begin
            ready <= 0;

            // probably have to register this one anyway
            // can expose it as an output of delay_ff
            if (busy_counter > 0) begin
                busy_counter <= busy_counter - 1;
            end else if (busy) begin
                ready <= 1;
                busy <= 0;
            end else if (read_en_in_r && !read_en_in_d || write_en_in_r && !write_en_in_d) begin
                ready <= 1;
                busy_counter <= 0;
                busy <= 0;
            end
        end
    end

    reg [7:0] data_t;

    always @(posedge clk) begin
        if (reset) begin
            data_t <= 0;
            write_en_out <= 0;
            address_out <= 0;
            data_out <= 0;
        end else if (USE_8BIT_BUS) begin
            if (write_en_in_r) begin
                if (address_in_r[0]) begin
                    data_out <= {data_in_r[7:0], data_t};
                    address_out <= address_in_r[6:1];
                    write_en_out <= 1;

                    data_t <= 0;
                end else begin
                    data_t <= data_in_r[7:0];
                    write_en_out <= 0;
                end
            end else begin
                address_out <= 0; 
                write_en_out <= 0;
            end
        end else begin
            address_out <= address_in;
            data_out <= data_in;

            // 1 cycle wstrb on rising edge only
            if (write_en_in && !write_en_in_r) begin
                write_en_out <= 1;
            end else begin
                write_en_out <= 0;
            end
        end
    end

endmodule
