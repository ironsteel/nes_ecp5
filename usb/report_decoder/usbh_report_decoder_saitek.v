// specific report decoder
// that converts saitek P3600 USB joystick
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

  localparam c_autofire_bits = $clog2(c_clk_hz/c_autofire_hz)-1;
  reg [c_autofire_bits-1:0] R_autofire;
  always @(posedge i_clk)
    R_autofire <= R_autofire + 1;

  wire [3:0] S_hat = i_report[63:60];
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

  // saitek P3600 joystick report decoder
  wire usbjoyl_l     = i_report[15:14] == 2'b00 ? 1'b1 : 1'b0;
  wire usbjoyl_r     = i_report[15:14] == 2'b11 ? 1'b1 : 1'b0;
  wire usbjoyl_u     = i_report[23:22] == 2'b00 ? 1'b1 : 1'b0;
  wire usbjoyl_d     = i_report[23:22] == 2'b11 ? 1'b1 : 1'b0;
  wire usbjoyl_btn   = i_report[56];
  wire usbjoyr_l     = i_report[31:30] == 2'b00 ? 1'b1 : 1'b0;
  wire usbjoyr_r     = i_report[31:30] == 2'b11 ? 1'b1 : 1'b0;
  wire usbjoyr_u     = i_report[39:38] == 2'b00 ? 1'b1 : 1'b0;
  wire usbjoyr_d     = i_report[39:38] == 2'b11 ? 1'b1 : 1'b0;
  wire usbjoyr_btn   = i_report[57];
  wire usbjoy_a      =   i_report[47] | i_report[46]; // A|X
  wire autofire_a    = ((i_report[52] | i_report[51]) & R_autofire[c_autofire_bits-1]); // A : ltrigger | rbumper
  wire usbjoy_b      =   i_report[48] | i_report[49]; // B|Y
  wire autofire_b    = ((i_report[53] | i_report[50]) & R_autofire[c_autofire_bits-1]); // B : rtrigger | lbumper
  wire usbjoy_start  = i_report[55];
  wire usbjoy_select = i_report[54]; // button labelled "BACK"

  reg [7:0] R_btn;
  wire ab_start_select = usbjoy_a & usbjoy_b & usbjoy_start & usbjoy_select;
  always @(posedge i_clk)
  begin
    o_btn <= R_btn | {6'b000000, autofire_b, autofire_a};
    if(i_report_valid)
      R_btn <=
      {
        usbjoyl_r|usbjoyr_r|R_hat_udlr[0]|ab_start_select,
        usbjoyl_l|usbjoyr_l|R_hat_udlr[1]|ab_start_select,
        usbjoyl_d|usbjoyr_d|R_hat_udlr[2]|ab_start_select,
        usbjoyl_u|usbjoyr_u|R_hat_udlr[3]|ab_start_select,
        usbjoy_start,
        usbjoy_select,
        usbjoy_b,
        usbjoy_a
      };
  end

endmodule
