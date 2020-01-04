// File vga.vhd translated with vhd2vl v3.0 VHDL to Verilog RTL translator
// vhd2vl settings:
//  * Verilog Module Declaration Style: 2001

// vhd2vl is Free (libre) Software:
//   Copyright (C) 2001 Vincenzo Liguori - Ocean Logic Pty Ltd
//     http://www.ocean-logic.com
//   Modifications Copyright (C) 2006 Mark Gonzales - PMC Sierra Inc
//   Modifications (C) 2010 Shankar Giri
//   Modifications Copyright (C) 2002-2017 Larry Doolittle
//     http://doolittle.icarus.com/~larry/vhd2vl/
//   Modifications (C) 2017 Rodrigo A. Melo
//
//   vhd2vl comes with ABSOLUTELY NO WARRANTY.  Always check the resulting
//   Verilog for correctness, ideally with a formal verification tool.
//
//   You are welcome to redistribute vhd2vl under certain conditions.
//   See the license (GPLv2) file included with the source for details.

// The result of translation follows.  Its copyright status should be
// considered unchanged from the original VHDL.

//-----------------------------------------------------------------[13.08.2016]
// VGA
//-----------------------------------------------------------------------------
// Engineer: MVV <mvvproject@gmail.com>
// no timescale needed

module vga(
  input I_CLK,
  input I_CLK_VGA,
  input [5:0] I_COLOR,
  input [8:0] I_HCNT,
  input [8:0] I_VCNT,
  output O_HSYNC,
  output O_VSYNC,
  output O_BLANK,
  output [7:0] O_RED,
  output [7:0] O_GREEN,
  output [7:0] O_BLUE
);


reg [23:0] rgb;
reg [5:0] pixel_out;
wire [15:0] addr_rd;
wire [15:0] addr_wr;
wire wren;
wire picture;
reg [8:0] window_hcnt = 9'b000000000;
reg [9:0] hcnt = 10'b0000000000;
reg [9:0] h = 10'b0000000000;
reg [9:0] vcnt = 10'b0000000000;
wire hsync;
wire vsync;
wire blank;  // ModeLine "640x480@60Hz"  25,175  640  656  752  800 480 490 492 525 -HSync -VSync
// Horizontal Timing constants  
parameter h_pixels_across = 640 - 1;
parameter h_sync_on = 656 - 1;
parameter h_sync_off = 752 - 1;
parameter h_end_count = 800 - 1;  // Vertical Timing constants
parameter v_pixels_down = 480 - 1;
parameter v_sync_on = 490 - 1;
parameter v_sync_off = 492 - 1;
parameter v_end_count = 525 - 1;

  framebuffer framebuffer_i(
    .clock_a(I_CLK),
    .data_a(I_COLOR),
    .address_a(addr_wr),
    .wren_a(wren),
    //
    .clock_b(I_CLK_VGA),
    .address_b(addr_rd),
    .q_b(pixel_out));

  // NES Palette -> RGB888 conversion (http://www.thealmightyguru.com/Games/Hacking/Wiki/index.php?title=NES_Palette)
  always @(pixel_out) begin
    case(pixel_out)
    6'b000000 : begin
      rgb <= 24'h7C7C7C;
    end
    6'b000001 : begin
      rgb <= 24'h0000FC;
    end
    6'b000010 : begin
      rgb <= 24'h0000BC;
    end
    6'b000011 : begin
      rgb <= 24'h4428BC;
    end
    6'b000100 : begin
      rgb <= 24'h940084;
    end
    6'b000101 : begin
      rgb <= 24'hA80020;
    end
    6'b000110 : begin
      rgb <= 24'hA81000;
    end
    6'b000111 : begin
      rgb <= 24'h881400;
    end
    6'b001000 : begin
      rgb <= 24'h503000;
    end
    6'b001001 : begin
      rgb <= 24'h007800;
    end
    6'b001010 : begin
      rgb <= 24'h006800;
    end
    6'b001011 : begin
      rgb <= 24'h005800;
    end
    6'b001100 : begin
      rgb <= 24'h004058;
    end
    6'b001101 : begin
      rgb <= 24'h000000;
    end
    6'b001110 : begin
      rgb <= 24'h000000;
    end
    6'b001111 : begin
      rgb <= 24'h000000;
    end
    6'b010000 : begin
      rgb <= 24'hBCBCBC;
    end
    6'b010001 : begin
      rgb <= 24'h0078F8;
    end
    6'b010010 : begin
      rgb <= 24'h0058F8;
    end
    6'b010011 : begin
      rgb <= 24'h6844FC;
    end
    6'b010100 : begin
      rgb <= 24'hD800CC;
    end
    6'b010101 : begin
      rgb <= 24'hE40058;
    end
    6'b010110 : begin
      rgb <= 24'hF83800;
    end
    6'b010111 : begin
      rgb <= 24'hE45C10;
    end
    6'b011000 : begin
      rgb <= 24'hAC7C00;
    end
    6'b011001 : begin
      rgb <= 24'h00B800;
    end
    6'b011010 : begin
      rgb <= 24'h00A800;
    end
    6'b011011 : begin
      rgb <= 24'h00A844;
    end
    6'b011100 : begin
      rgb <= 24'h008888;
    end
    6'b011101 : begin
      rgb <= 24'h000000;
    end
    6'b011110 : begin
      rgb <= 24'h000000;
    end
    6'b011111 : begin
      rgb <= 24'h000000;
    end
    6'b100000 : begin
      rgb <= 24'hF8F8F8;
    end
    6'b100001 : begin
      rgb <= 24'h3CBCFC;
    end
    6'b100010 : begin
      rgb <= 24'h6888FC;
    end
    6'b100011 : begin
      rgb <= 24'h9878F8;
    end
    6'b100100 : begin
      rgb <= 24'hF878F8;
    end
    6'b100101 : begin
      rgb <= 24'hF85898;
    end
    6'b100110 : begin
      rgb <= 24'hF87858;
    end
    6'b100111 : begin
      rgb <= 24'hFCA044;
    end
    6'b101000 : begin
      rgb <= 24'hF8B800;
    end
    6'b101001 : begin
      rgb <= 24'hB8F818;
    end
    6'b101010 : begin
      rgb <= 24'h58D854;
    end
    6'b101011 : begin
      rgb <= 24'h58F898;
    end
    6'b101100 : begin
      rgb <= 24'h00E8D8;
    end
    6'b101101 : begin
      rgb <= 24'h787878;
    end
    6'b101110 : begin
      rgb <= 24'h000000;
    end
    6'b101111 : begin
      rgb <= 24'h000000;
    end
    6'b110000 : begin
      rgb <= 24'hFCFCFC;
    end
    6'b110001 : begin
      rgb <= 24'hA4E4FC;
    end
    6'b110010 : begin
      rgb <= 24'hB8B8F8;
    end
    6'b110011 : begin
      rgb <= 24'hD8B8F8;
    end
    6'b110100 : begin
      rgb <= 24'hF8B8F8;
    end
    6'b110101 : begin
      rgb <= 24'hF8A4C0;
    end
    6'b110110 : begin
      rgb <= 24'hF0D0B0;
    end
    6'b110111 : begin
      rgb <= 24'hFCE0A8;
    end
    6'b111000 : begin
      rgb <= 24'hF8D878;
    end
    6'b111001 : begin
      rgb <= 24'hD8F878;
    end
    6'b111010 : begin
      rgb <= 24'hB8F8B8;
    end
    6'b111011 : begin
      rgb <= 24'hB8F8D8;
    end
    6'b111100 : begin
      rgb <= 24'h00FCFC;
    end
    6'b111101 : begin
      rgb <= 24'hF8D8F8;
    end
    6'b111110 : begin
      rgb <= 24'h000000;
    end
    6'b111111 : begin
      rgb <= 24'h000000;
    end
    endcase
  end

  always @(posedge I_CLK_VGA) begin
    if(h == h_end_count) begin
      h <= {10{1'b0}};
    end
    else begin
      h <= h + 1;
    end
    if(h == 7) begin
      hcnt <= {10{1'b0}};
    end
    else begin
      hcnt <= hcnt + 1;
      if(hcnt == 63) begin
        window_hcnt <= {9{1'b0}};
      end
      else begin
        window_hcnt <= window_hcnt + 1;
      end
    end
    if(hcnt == h_sync_on) begin
      if(vcnt == v_end_count) begin
        vcnt <= {10{1'b0}};
      end
      else begin
        vcnt <= vcnt + 1;
      end
    end
  end

  assign wren = (I_HCNT < 256) && (I_VCNT < 240) ? 1'b1 : 1'b0;
  assign addr_wr = {I_VCNT[7:0],I_HCNT[7:0]};
  assign addr_rd = {vcnt[8:1],window_hcnt[8:1]};
  assign blank = (hcnt > h_pixels_across) || (vcnt > v_pixels_down) ? 1'b1 : 1'b0;
  assign picture = (blank == 1'b0) && (hcnt > 64 && hcnt < 576) ? 1'b1 : 1'b0;
  assign O_HSYNC = (hcnt <= h_sync_on) || (hcnt > h_sync_off) ? 1'b1 : 1'b0;
  assign O_VSYNC = (vcnt <= v_sync_on) || (vcnt > v_sync_off) ? 1'b1 : 1'b0;
  assign O_RED = picture == 1'b1 ? rgb[23:16] : {8{1'b0}};
  assign O_GREEN = picture == 1'b1 ? rgb[15:8] : {8{1'b0}};
  assign O_BLUE = picture == 1'b1 ? rgb[7:0] : {8{1'b0}};
  assign O_BLANK = blank;

endmodule
