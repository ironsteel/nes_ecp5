// specific report decoder
// that converts darfon/dragonrise USB joystick
// HID report to NES 8-bit button state

// For this core to work properly, press central silver button
// to select report type - upper left LED marked "1" should turn ON

module usbh_report_decoder
#(
  parameter c_clk_hz=48000000,
  parameter c_autofire_hz=10
)
(
  input  wire         i_clk, // same as USB core clock domain
  input  wire [159:0] i_report,
  input  wire         i_report_valid,
  output reg    [7:0] o_btn
);

  localparam c_autofire_bits = $clog2(c_clk_hz/c_autofire_hz)-1;
  reg [c_autofire_bits-1:0] R_autofire;
  always @(posedge i_clk)
    R_autofire <= R_autofire + 1;

  // xbox360 joystick report decoder (left joystick or hat)
  wire usbjoy_l      =  (i_report[63:61] == 3'b100 ? 1'b1 : 1'b0) | i_report[18];
  wire usbjoy_r      =  (i_report[63:61] == 3'b011 ? 1'b1 : 1'b0) | i_report[19];
  wire usbjoy_u      =  (i_report[79:77] == 3'b011 ? 1'b1 : 1'b0) | i_report[16];
  wire usbjoy_d      =  (i_report[79:77] == 3'b100 ? 1'b1 : 1'b0) | i_report[17];
  wire usbjoy_a      =   i_report[28] | i_report[31]; // A or Y
  wire autofire_a    = ((i_report[39] | i_report[25]) & R_autofire[c_autofire_bits-1]); // A : ltrigger | rbumper 
  wire usbjoy_b      =   i_report[29] | i_report[30]; // B or X
  wire autofire_b    = ((i_report[47] | i_report[24]) & R_autofire[c_autofire_bits-1]); // B : rtrigger | lbumper
  wire usbjoy_start  =   i_report[20];
  wire usbjoy_select =   i_report[21]; // button labelled "BACK"

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
