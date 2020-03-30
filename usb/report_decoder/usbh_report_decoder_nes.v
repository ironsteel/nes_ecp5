// specific report decoder
// that converts NES USB joystick
// HID report to NES 8-bit button state

module usbh_report_decoder
#(
  parameter c_clk_hz=6000000,
  parameter c_autofire_hz=10
)
(
  input  wire        i_clk, // same as USB core clock domain
  input  wire [63:0] i_report,
  input  wire        i_report_valid,
  output reg   [7:0] o_btn
);
/*
  localparam c_autofire_bits = $clog2(c_clk_hz/c_autofire_hz)-1;
  reg [c_autofire_bits-1:0] R_autofire;
  always @(posedge i_clk)
    R_autofire <= R_autofire + 1;
*/
  // NES USB joystick report decoder
  wire usbjoy_l      = i_report[31:30] == 2'b00 ? 1'b1 : 1'b0;
  wire usbjoy_r      = i_report[31:30] == 2'b11 ? 1'b1 : 1'b0;
  wire usbjoy_u      = i_report[39:38] == 2'b00 ? 1'b1 : 1'b0;
  wire usbjoy_d      = i_report[39:38] == 2'b11 ? 1'b1 : 1'b0;
  wire usbjoy_a      = i_report[45];
  wire usbjoy_b      = i_report[44];
  wire usbjoy_start  = i_report[53];
  wire usbjoy_select = i_report[52];

  reg [7:0] R_btn;
  always @(posedge i_clk)
  begin
    o_btn <= R_btn; // | {6'b000000, autofire_b, autofire_a};
    if(i_report_valid)
      R_btn <=
      {
        usbjoy_r, usbjoy_l, usbjoy_d, usbjoy_u,
        usbjoy_start, usbjoy_select, usbjoy_b, usbjoy_a
      };
  end

endmodule
