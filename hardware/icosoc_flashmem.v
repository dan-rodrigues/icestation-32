// this is a modified version of icosoc_flashmem.v
// https://github.com/cliffordwolf/icotools/blob/master/icosoc/common/icosoc_flashmem.v

// changes from the original: quick and dirty DSPI
// eventually this module can just be rewritten

module icosoc_flashmem(
    input clk,
    input resetn,
    input continue_reading,

    input valid,
    output reg ready,
    input [23:0] addr,
    output reg [31:0] rdata,

    output reg spi_cs,
    output reg spi_sclk,
    output reg [3:0] flash_out,
    output reg [3:0] flash_oe,
    input [3:0] flash_in
);
    reg [7:0] buffer;
    reg [3:0] xfer_cnt;
    reg [3:0] state;

    reg sending_cmd;
    reg sending;

    reg [2:0] oe_count;
    wire oe_nx = oe_count && sending;

    always @(posedge clk) begin
        ready <= 0;
        if (!resetn || !valid || (ready && !continue_reading)) begin
            spi_cs <= 1;
            spi_sclk <= 1;
            xfer_cnt <= 0;
            state <= 0;

            flash_oe <= 0;
            flash_out <= 0;
            sending_cmd <= 0;
            sending <= 0;
            oe_count <= 0;
        end else begin
            spi_cs <= 0;

            if (xfer_cnt) begin
                if (sending_cmd) begin
                    if (spi_sclk) begin
                        spi_sclk <= 0;
                        flash_out[0] <= buffer[7];
                        flash_oe <= 4'b0001;
                    end else begin
                        spi_sclk <= 1;
                        buffer <= {buffer, flash_in[1]};
                        xfer_cnt <= xfer_cnt - 1;
                    end
                end else begin
                    if (spi_sclk) begin
                        spi_sclk <= 0;
                        flash_out[1:0] <= buffer[7:6];
                        flash_oe <= {2'b00, {2{oe_nx}}};

                        oe_count <= oe_count == 0 ? 0 : oe_count - 1;
                    end else begin
                        spi_sclk <= 1;
                        buffer <= {buffer, flash_in[1:0]};
                        xfer_cnt <= xfer_cnt - 1;
                    end
                end
            end else
            case (state)
                0: begin
                    buffer <= 'hbb;
                    xfer_cnt <= 8;
                    state <= 1;
                    sending_cmd <= 1;
                    oe_count <= 8;
                    sending <= 1;
                end
                1: begin
                    buffer <= addr[23:16];
                    xfer_cnt <= 4;
                    state <= 2;
                    sending_cmd <= 0;
                    oe_count <= 4;
                    sending <= 1;
                end
                2: begin
                    buffer <= addr[15:8];
                    xfer_cnt <= 4;
                    state <= 3;
                    sending_cmd <= 0;
                    oe_count <= 4;
                    sending <= 1;
                end
                3: begin
                    buffer <= addr[7:0];
                    xfer_cnt <= 4;
                    state <= 4;
                    sending_cmd <= 0;
                    oe_count <= 4;
                    sending <= 1;
                end
                4: begin
                    buffer <= 0; // M7-0
                    xfer_cnt <= 4;
                    state <= 5;
                    sending_cmd <= 0;
                    oe_count <= 3;
                    sending <= 1;
                end
                5: begin
                    buffer <= 0; // receiving first byte
                    xfer_cnt <= 4;
                    state <= 6;
                    sending_cmd <= 0;
                    sending <= 0;
                end
                6: begin
                    rdata[7:0] <= buffer;
                    xfer_cnt <= 4;
                    state <= 7;
                    sending_cmd <= 0;
                    sending <= 0;
                end
                7: begin
                    rdata[15:8] <= buffer;
                    xfer_cnt <= 4;
                    state <= 8;
                    sending_cmd <= 0;
                    sending <= 0;
                end
                8: begin
                    rdata[23:16] <= buffer;
                    xfer_cnt <= 4;
                    state <= 9;
                    sending_cmd <= 0;
                end
                9: begin
                    rdata[31:24] <= buffer;
                    sending_cmd <= 0;
                    sending <= 0;
                    ready <= 1;

                    if (continue_reading) begin
                        xfer_cnt <= 4;
                        state <= 6;
                    end
                end
            endcase
        end
    end
endmodule

