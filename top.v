module top(
	input clk,
	output flash_csn,
	output flash_mosi,
	input flash_miso,

	output led,

	output dbg_flash_mosi,
	output dbg_flash_miso,
	output dbg_flash_csn,
	output dbg_flash_sck,

	input btn
);


wire clock;
wire locked;

wire reset = !locked || !btn;

wire flash_sck;

wire tristate = 1'b0;

USRMCLK u1 (.USRMCLKI(flash_sck), .USRMCLKTS(tristate));

pll pll_i(
	.clkin(clk),
	.clkout0(clock),
	.locked(locked)
);

assign dbg_flash_sck = flash_sck;
assign dbg_flash_mosi = flash_mosi;
assign dbg_flash_miso = flash_miso;
assign dbg_flash_csn = flash_csn;

cart_mem cart (
	.clock(clock),
	.reset(reset),
	.reload(1'b0),
	.index({4'b0000}),
	.cart_ready(led),

	.flash_csn(flash_csn),
	.flash_mosi(flash_mosi),
	.flash_miso(flash_miso),
	.flash_sck(flash_sck)
);

endmodule
