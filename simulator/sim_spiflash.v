// This file is adapted from the icotools repo:
// https://github.com/cliffordwolf/icotools

// Quick and dirty one-word-per-command hack
// This is the only use case for as long as this model remains in the project
// In the short term this will be replaced as work starts on supporting DSPI/QSPI

// This also avoids having to use SPI_FLASH_CS as an async reset which impacts sim performance

module sim_spiflash (
    input      SPI_FLASH_CS,
    output reg SPI_FLASH_MISO = 0,
    input      SPI_FLASH_MOSI,
    input      SPI_FLASH_SCLK
);
    reg [7:0] buffer = 0;
    reg [3:0] bitcount = 0;
    reg [23:0] bytecount = 0;

    reg [7:0] spi_cmd = 0;
    reg [23:0] spi_addr = 0;

    // 16 MB (128Mb) Flash
    reg [7:0] memory [0:16*1024*1024-1];

    always @(posedge SPI_FLASH_SCLK) begin
        if (!SPI_FLASH_CS && bitcount == 0) begin
            if (bytecount == 1)
                spi_cmd <= buffer;

            if (spi_cmd == 'h03) begin
                if (bytecount == 2)
                    spi_addr[23:16] <= buffer;

                if (bytecount == 3)
                    spi_addr[15:8] <= buffer;

                if (bytecount == 4)
                    spi_addr[7:0] <= buffer;

                if (bytecount >= 4) begin
                    spi_addr <= spi_addr + 1;
                end
            end
        end
    end

    always @(negedge SPI_FLASH_SCLK) begin
        if (!SPI_FLASH_CS) begin
            SPI_FLASH_MISO <= buffer[7];
        end else begin
            SPI_FLASH_MISO <= 0;
        end
    end

    always @(posedge SPI_FLASH_SCLK) begin
        if (!SPI_FLASH_CS) begin
            bitcount <= bitcount + 1;

            if (bitcount == 7) begin
                bitcount <= 0;
                bytecount <= bytecount + 1;
            end

            if (bitcount == 7 && (bytecount >= 3) && spi_cmd == 8'h03) begin
                if (bytecount <= 7) begin
                    if (bytecount != 7) begin
                        buffer <= memory[spi_addr];
                    end else begin
                        buffer <= 0;
                        bitcount <= 0;
                        bytecount <= 0;
                        spi_cmd <= 0;
                    end
                end
            end else begin
                buffer <= {buffer, SPI_FLASH_MOSI};
            end
        end else begin
            buffer <= 0;
            bitcount <= 0;
            bytecount <= 0;
        end
    end

endmodule
