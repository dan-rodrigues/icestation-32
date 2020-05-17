module sim_spiflash (
	input      SPI_FLASH_CS,
	output reg SPI_FLASH_MISO,
	input      SPI_FLASH_MOSI,
	input      SPI_FLASH_SCLK
);
	reg [7:0] buffer;
	integer bitcount = 0;
	integer bytecount = 0;

	reg [7:0] spi_cmd;
	reg [23:0] spi_addr;

	// 16 MB (128Mb) Flash
	reg [7:0] memory [0:16*1024*1024-1];

	task spi_action;
		begin
			// if (bytecount == 1)
			// 	$write("<SPI>");
			// $write("<SPI:%02x>", buffer);
			// $fflush;

			if (bytecount == 1)
				spi_cmd = buffer;

			if (spi_cmd == 'h03) begin
				if (bytecount == 2)
					spi_addr[23:16] = buffer;

				if (bytecount == 3)
					spi_addr[15:8] = buffer;

				if (bytecount == 4)
					spi_addr[7:0] = buffer;

				if (bytecount >= 4) begin
					buffer = memory[spi_addr];
					spi_addr = spi_addr + 1;
				end
			end
		end
	endtask

	always @(SPI_FLASH_CS) begin
		if (SPI_FLASH_CS) begin
			buffer = 0;
			bitcount = 0;
			bytecount = 0;
			SPI_FLASH_MISO = 0;
		end
	end

	always @(SPI_FLASH_CS, SPI_FLASH_SCLK) begin
		if (!SPI_FLASH_CS && !SPI_FLASH_SCLK) begin
			SPI_FLASH_MISO = buffer[7];
		end
	end

	always @(posedge SPI_FLASH_SCLK) begin
		if (!SPI_FLASH_CS) begin
			buffer = {buffer, SPI_FLASH_MOSI};
			bitcount = bitcount + 1;
			if (bitcount == 8) begin
				bitcount = 0;
				bytecount = bytecount + 1;
				spi_action;
			end
		end
	end
endmodule

