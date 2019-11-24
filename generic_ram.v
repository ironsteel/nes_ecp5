// Simple, platform-agnostic single-ported RAM

module generic_ram(clock, reset, address, wren, write_data, read_data);

parameter integer WIDTH = 8;
parameter integer WORDS = 2048;
localparam ADDR_BITS = $clog2(WORDS-1);

input clock;
input reset;
input [ADDR_BITS-1:0] address;
input wren;
input [WIDTH-1:0] write_data;
output reg [WIDTH-1:0] read_data;

reg [WIDTH-1:0] mem[0:WORDS-1];

reg [ADDR_BITS-1:0] a_prereg;
reg [WIDTH-1:0] d_prereg;
reg wren_prereg;

always @(posedge clock) begin
  if (reset == 1'b1) begin
    wren_prereg <= 0;
    a_prereg <= 0;
    d_prereg <= 0;
  end else begin
    wren_prereg <= wren;
    a_prereg <= address;
    d_prereg <= write_data;
  end

  
  read_data <= mem[a_prereg];
  if (wren_prereg) mem[a_prereg] <= d_prereg;
end

endmodule
