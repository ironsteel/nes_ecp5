module dpram(
  input clock_a,
  input [6:0] address_a,
  input wren_a,
  input byteena_a,
  input [7:0] data_a,
  output reg [7:0] q_a,


  input clock_b,
  input [6:0] address_b,
  input wren_b,
  input byteena_b,
  input [7:0] data_b,
  output reg [7:0] q_b);

reg [7:0] ram[128];

always @(posedge clock_a) begin
  if (wren_a)
    ram[address_a] <= data_a;
  q_a <= ram[address_a];
end

always @(posedge clock_b) begin
  if (wren_b)
    ram[address_b] <= data_b;
  q_b <= ram[address_b];
end

endmodule
