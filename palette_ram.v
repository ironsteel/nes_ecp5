module PaletteRam
(
	input clk,
	input ce,
	input [4:0] addr,
	input [5:0] din,
	output [5:0] dout,
	input write
);

reg [5:0] palette[32]; 

initial $readmemh("ppu_palette.hex", palette);
// Force read from backdrop channel if reading from any addr 0.
// Do this to the input, not here
//wire [4:0] addr2 = (addr[1:0] == 0) ? 5'd0 : addr;
// If 0x0,4,8,C: mirror every 0x10
wire [4:0] addr2 = (addr[1:0] == 0) ? {1'b0, addr[3:0]} : addr;
assign dout = palette[addr2];

always @(posedge clk) if (ce && write) begin
	palette[addr2] <= din;
end

endmodule  // PaletteRam

