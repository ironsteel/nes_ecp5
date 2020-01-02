`timescale 10 ns/ 1 ps 

module clocks(
  input clock25,
  output clock21,
  output reg clock_locked);

`ifdef SIM
  initial clock_locked = 1;
  reg clock21477 = 0;
  always #2.34 clock21477 = ~clock21477;
  assign clock21 = clock21477;
`else

  wire locked_pre;
  wire clock;
  pll pll_i(
    .clkin(clock25),
    .clkout0(clock),
    .locked(locked_pre)
  );

  DCCA gb_clock1(
    .CLKI(clock),
    .CE(1),
    .CLKO(clock21)
  );

  always @(posedge clock21)
    clock_locked <= locked_pre;

`endif


endmodule
