// specific report decoder
// that converts darfon/dragonrise USB joystick
// HID report to NES 8-bit button state

// For this core to work properly,
// set HID to accept strict report of exactly 8 bytes in top.v
// C_report_length=8, C_report_length_strict=1
// or maybe workaround:
// press central silver button toggles upper left LED marked "1"
// joystick will work reliably when upper left LED marked "1" is OFF
// if upper left LED marked "1" is ON, fake keypresses will be randomly generated

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

  localparam c_autofire_bits = $clog2(c_clk_hz/c_autofire_hz)-1;
  reg [c_autofire_bits-1:0] R_autofire;
  always @(posedge i_clk)
    R_autofire <= R_autofire + 1;

  wire [3:0] S_hat = i_report[43:40];
  reg  [3:0] R_hat_udlr;
  always @(posedge i_clk)
    R_hat_udlr <= S_hat == 4'b0000 ? 4'b1000 : // up
                  S_hat == 4'b0001 ? 4'b1001 : // up+right
                  S_hat == 4'b0010 ? 4'b0001 : // right
                  S_hat == 4'b0011 ? 4'b0101 : // down+right
                  S_hat == 4'b0100 ? 4'b0100 : // down
                  S_hat == 4'b0101 ? 4'b0110 : // down+left
                  S_hat == 4'b0110 ? 4'b0010 : // left
                  S_hat == 4'b0111 ? 4'b1010 : // up+left
                                     4'b0000 ; // 4'b1111 when not pressed

  // darfon/dragonrise joystick report decoder
  wire usbjoy_l      =  (i_report[ 7:6 ] == 2'b00 ? 1'b1 : 1'b0) | R_hat_udlr[1];
  wire usbjoy_r      =  (i_report[ 7:6 ] == 2'b11 ? 1'b1 : 1'b0) | R_hat_udlr[0];
  wire usbjoy_u      =  (i_report[15:14] == 2'b00 ? 1'b1 : 1'b0) | R_hat_udlr[3];
  wire usbjoy_d      =  (i_report[15:14] == 2'b11 ? 1'b1 : 1'b0) | R_hat_udlr[2];
  wire usbjoy_a      =   i_report[46] | i_report[44]; // A or Y
  wire autofire_a    = ((i_report[50] | i_report[49]) & R_autofire[c_autofire_bits-1]); // A : ltrigger | rbumper
  wire usbjoy_b      =   i_report[45] | i_report[47]; // B or X 
  wire autofire_b    = ((i_report[51] | i_report[48]) & R_autofire[c_autofire_bits-1]); // B : rtrigger | lbumper
  wire usbjoy_start  =   i_report[53];
  wire usbjoy_select =   i_report[52]; // button labelled "BACK"

  reg [7:0] R_btn;
  always @(posedge i_clk)
  begin
    o_btn <= R_btn | {6'b000000, autofire_b, autofire_a};
    if(i_report_valid)
      R_btn <=
      {
        usbjoy_r, usbjoy_l, usbjoy_d, usbjoy_u,
        usbjoy_start, usbjoy_select, usbjoy_b, usbjoy_a
      };
  end

endmodule