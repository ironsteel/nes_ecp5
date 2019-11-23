// SPI flash memory interface, taken from the icosoc project

module icosoc_flashmem (
	input clk, reset,

	input valid,
	output reg ready,
	input [23:0] addr,
	output reg [15:0] rdata,

	output reg spi_cs,
	output reg spi_sclk,
	output reg spi_mosi,
	input spi_miso
);
	reg [7:0] buffer;
	reg [3:0] xfer_cnt;
	reg [3:0] state;

	always @(posedge clk) begin
		ready <= 0;
		if (reset || !valid || ready) begin
			spi_cs <= 1;
			spi_sclk <= 1;
			xfer_cnt <= 0;
			state <= 0;
		end else begin
			spi_cs <= 0;
			if (xfer_cnt) begin
				if (spi_sclk) begin
					spi_sclk <= 0;
					spi_mosi <= buffer[7];
				end else begin
					spi_sclk <= 1;
					buffer <= {buffer, spi_miso};
					xfer_cnt <= xfer_cnt - 1;
				end
			end else
			case (state)
				0: begin
					buffer <= 'h03;
					xfer_cnt <= 8;
					state <= 1;
				end
				1: begin
					buffer <= addr[23:16];
					xfer_cnt <= 8;
					state <= 2;
				end
				2: begin
					buffer <= addr[15:8];
					xfer_cnt <= 8;
					state <= 3;
				end
				3: begin
					buffer <= addr[7:0];
					xfer_cnt <= 8;
					state <= 4;
				end
				4: begin
					xfer_cnt <= 8;
					state <= 5;
				end
				5: begin
					rdata[7:0] <= buffer;
					xfer_cnt <= 8;
					state <= 6;
				end
				6: begin
					rdata[15:8] <= buffer;
					ready <= 1;
				end
			endcase
		end
	end
endmodule
