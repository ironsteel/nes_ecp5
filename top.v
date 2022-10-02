module top
#(
  parameter use_external_nes_joypad=0,
  parameter C_audio=2, // 0: direct MSB 4->4 bit DAC, 1: 16->1 bit PWM-DAC, 2: 16->4 bit PWM-DAC
  parameter C_usb_speed=0,  // 0:6 MHz USB1.0, 1:48 MHz USB1.1, -1: USB disabled,
  // xbox360 : C_report_bytes=20, C_report_bytes_strict=1
  // darfon  : C_report_bytes= 8, C_report_bytes_strict=1
  parameter C_report_bytes=8, // 8:usual joystick, 20:xbox360
  parameter C_report_bytes_strict=1, // 0:when report length is variable/unknown
  parameter C_autofire_hz=10, // joystick trigger and bumper
  parameter C_osd_usb=2, // 0:OSD onboard BTN's, 1:OSD USB joystick, 2:both
  parameter C_osd_transparency=1, // 0:opaque 1:transparent OSD menu
  // choose one: C_flash_loader or C_esp32_loader
  parameter C_flash_loader=0, // fujprog -j flash -f 0x200000 100in1.img
  parameter C_esp32_loader=1 // usage: import nes # for OSD press together A B SELECT START or all 4 directions
)
(
  input  clk_25mhz,
  output flash_csn,
  output flash_mosi,
  input  flash_miso,

  output [7:0]  led,

  output sdram_csn,       // chip select
  output sdram_clk,       // clock to SDRAM
  output sdram_cke,       // clock enable to SDRAM
  output sdram_rasn,      // SDRAM RAS
  output sdram_casn,      // SDRAM CAS
  output sdram_wen,       // SDRAM write-enable
  output [12:0] sdram_a,  // SDRAM address bus
  output  [1:0] sdram_ba, // SDRAM bank-address
  output  [1:0] sdram_dqm,// byte select
  inout  [15:0] sdram_d,  // data bus to/from SDRAM

  input   [6:0] btn,

  input  usb_fpga_dp,
  inout  usb_fpga_bd_dp,
  inout  usb_fpga_bd_dn,
  output usb_fpga_pu_dp,
  output usb_fpga_pu_dn,

  input  ftdi_txd,
  output ftdi_rxd,

  input  wifi_txd,
  output wifi_rxd,
  output wifi_gpio0,
  input  wifi_gpio5,
  input  wifi_gpio16,

  inout  sd_clk, sd_cmd,
  inout   [3:0] sd_d,

  inout  [27:0] gp, gn,

  // DVI out
  output  [3:0] gpdi_dp,
  output  [3:0] audio_l, audio_r
);
  wire  btn_start = ~btn[0];
  wire  btn_b     =  btn[1];
  wire  btn_a     =  btn[2];
  wire  btn_up    =  btn[3];
  wire  btn_down  =  btn[4];
  wire  btn_left  =  btn[5];
  wire  btn_right =  btn[6];
  wire  btn_select = btn_start & btn_a;


  // passthru to ESP32 micropython serial console
  assign wifi_rxd = ftdi_txd;
  assign ftdi_rxd = wifi_txd;

  assign sd_d[3] = 1'bz; // FPGA pin pullup sets SD card inactive at SPI bus
  //assign sd_d[2] = 1'bz;

  wire [3:0] dvi_usb_clocks;
  wire dvi_clock_locked;
  ecp5pll
  #(
      .in_hz( 25*1000000),
    .out0_hz(125*1000000),
    .out1_hz( 48*1000000), .out1_tol_hz(100000),
    .out2_hz(  6*1000000), .out2_tol_hz( 10000),
    .out3_hz( 25*1000000)
  )
  clk_dvi_usb_inst
  (
    .clk_i(clk_25mhz),
    .clk_o(dvi_usb_clocks),
    .locked(dvi_clock_locked)
  );
  wire clk_shift = dvi_usb_clocks[0];
  wire clk_pixel = dvi_usb_clocks[3];
  wire clk_48MHz = dvi_usb_clocks[1]; // USB1.1
  wire clk_6MHz  = dvi_usb_clocks[2]; // USB1.0

  wire [3:0] sys_sdram_clocks;
  wire sys_sdram_clocks_locked;
  ecp5pll
  #(
      .in_hz( 25*1000000),
    .out0_hz(   85714285), // 4*25*6/7 MHz
    .out1_hz(   85714285), .out1_deg(270), // 0-45 ok, 90 fail, 150-359 ok
    .out2_hz(   21428571), //   25*6/7 MHz
    .out3_hz(   21428571)  // not used
  )
  clk_sdram_sys_inst
  (
    .clk_i(clk_25mhz),
    .clk_o(sys_sdram_clocks),
    .locked(sys_sdram_clocks_locked)
  );
  wire clock_sdram_core = sys_sdram_clocks[0];
  wire clock_sdram_chip = sys_sdram_clocks[1];
  wire clock            = sys_sdram_clocks[2]; // NES system clock
  reg clock_locked;
  always @(posedge clock)
    clock_locked <= sys_sdram_clocks_locked;


  wire flash_sck;
  wire tristate = 1'b0;
  USRMCLK u1 (.USRMCLKI(flash_sck), .USRMCLKTS(tristate));

  reg [23:0] R_reset = 24'hFFFFFF;
  always @(posedge clock)
  begin
    if(clock_locked == 0 || dvi_clock_locked == 0)
      R_reset <= 24'hFFFFFF;
    else
      if(R_reset[23])
        R_reset <= R_reset-1;
  end

  wire scandoubler_disable;

  wire  [8:0] cycle;
  wire  [8:0] scanline;
  wire  [5:0] color;
  wire [15:0] sample;

  wire memory_write;
  wire [21:0] memory_addr_cpu, memory_addr_ppu;
  wire memory_read_cpu, memory_read_ppu;
  wire memory_write_cpu, memory_write_ppu;
  wire  [7:0] memory_din_cpu, memory_din_ppu;
  wire  [7:0] memory_dout_cpu, memory_dout_ppu;
  wire [31:0] mapper_flags;
  
  wire load_done;
  wire  [7:0] flash_loader_data_out;
  wire [21:0] game_loader_address;
  reg  [21:0] load_address_reg;
  wire  [7:0] game_loader_mem;
  wire flash_loader_data_ready;
  wire loader_write;

  wire clk_usb;  // 6 MHz USB1.0 or 48 MHz USB1.1
  generate if (C_usb_speed == 0) begin: G_low_speed
      assign clk_usb = clk_6MHz;
  end
  endgenerate
  generate if (C_usb_speed == 1) begin: G_full_speed
      assign clk_usb = clk_48MHz;
  end
  endgenerate

  assign usb_fpga_pu_dp = 1'b0;
  assign usb_fpga_pu_dn = 1'b0;
  wire [C_report_bytes*8-1:0] S_report;
  wire S_report_valid;
  wire [7:0] usb_buttons;
  generate if (C_usb_speed >= 0) begin
  usbh_host_hid
  #(
    .C_usb_speed(C_usb_speed), // '0':Low-speed '1':Full-speed
    .C_report_length(C_report_bytes),
    .C_report_length_strict(C_report_bytes_strict)
  )
  us2_hid_host_inst
  (
    .clk(clk_usb), // 6 MHz for low-speed USB1.0 device or 48 MHz for full-speed USB1.1 device
    .bus_reset(~dvi_clock_locked),
    .led(), // debug output
    .usb_dif(usb_fpga_dp),
    //.usb_dif(usb_fpga_bd_dp), // for trellis < 2020-03-08
    .usb_dp(usb_fpga_bd_dp),
    .usb_dn(usb_fpga_bd_dn),
    .hid_report(S_report),
    .hid_valid(S_report_valid)
  );
  
  usbh_report_decoder
  #(
    .c_autofire_hz(C_autofire_hz)
  )
  usbh_report_decoder_inst
  (
    .i_clk(clk_usb),
    .i_report(S_report),
    .i_report_valid(S_report_valid),
    .o_btn(usb_buttons)
  );
    assign led = usb_buttons;
  end
  else
    assign led = {1'b0,btn};
  endgenerate

  wire sys_reset;

  generate
  if(C_flash_loader)
  begin
  flash_loader
  flash_load_i
  (
    .clock(clock),
    .reset(sys_reset),
    .reload(1'b0),
    .index({4'b0000}),
    .load_write_data(flash_loader_data_out),
    .data_valid(flash_loader_data_ready),
    //Flash load interface
    .flash_csn(flash_csn),
    .flash_sck(flash_sck),
    .flash_mosi(flash_mosi),
    .flash_miso(flash_miso)
  );
  assign sys_reset = R_reset[23];
  end
  if(C_esp32_loader)
  begin
    reg [6:0] R_btn_joy;
    if(C_osd_usb==0)
      always @(posedge clock)
        R_btn_joy <= btn;
    if(C_osd_usb==1)
      always @(posedge clock)
        R_btn_joy <=
        {
            usb_buttons[7], // 6 right
            usb_buttons[6], // 5 left
            usb_buttons[5], // 4 down
            usb_buttons[4], // 3 up
            1'b0,           // 2 B
            1'b0,           // 1 A
            1'b1            // 0 start
        };
    if(C_osd_usb==2)
      always @(posedge clock)
        R_btn_joy <= btn |
        {
            usb_buttons[7], // 6 right
            usb_buttons[6], // 5 left
            usb_buttons[5], // 4 down
            usb_buttons[4], // 3 up
            1'b0,           // 2 B
            1'b0,           // 1 A
            1'b1            // 0 start
        };
    wire [31:0] spi_ram_addr;
    wire spi_rd;
    reg  [7:0] R_spi_data_in;
    wire spi_wr;
    reg R_spi_wr;
    wire irq;
    spi_ram_btn
    #(
      .c_addr_bits($bits(spi_ram_addr)),
      .c_sclk_capable_pin(1'b0)
    )
    spi_ram_btn_inst
    (
      .clk(clock),
      .csn(~wifi_gpio5),
      .sclk(wifi_gpio16),
      .mosi(sd_d[1]), // wifi_gpio4
      .miso(sd_d[2]), // wifi_gpio12
      .btn(R_btn_joy),
      .irq(irq),
      .rd(spi_rd),
      .wr(spi_wr),
      .addr(spi_ram_addr),
      .data_in(R_spi_data_in), // R_spi_data_in used to read BTN state
      .data_out(flash_loader_data_out)
    );
    assign wifi_gpio0 = ~irq;

    reg [7:0] R_cpu_control;
    always @(posedge clock) begin
      R_spi_wr <= spi_wr;
      if (spi_wr && spi_ram_addr[31:24] == 8'hFF) begin
        R_cpu_control <= flash_loader_data_out;
      end
    end
    assign sys_reset = R_cpu_control[0];
    wire flash_loader_data_ready = spi_wr & ~R_spi_wr;
  end
  endgenerate

  game_loader
  game_loader_i
  (
    .clk(clock),
    .reset(sys_reset),
    .indata(flash_loader_data_out),
    .indata_clk(flash_loader_data_ready),
    .mem_addr(game_loader_address),
    .mem_data(game_loader_mem),
    .mem_write(loader_write),
    .mapper_flags(mapper_flags),
    .done(load_done)
  );

  // loader_write -> clock when data available
  always @(posedge clock) begin
    if(loader_write) begin
      loader_write_triggered	<= 1'b1;
      loader_addr_mem		<= game_loader_address;
      loader_write_data_mem	<= game_loader_mem;
    end

    if(nes_ce == 3) begin
      loader_write_mem <= loader_write_triggered;
      if(loader_write_triggered)
        loader_write_triggered <= 1'b0;
    end
  end

  // reset after download
  reg [7:0] download_reset_cnt;
  wire download_reset = download_reset_cnt != 0;
  always @(posedge clock) begin
    if(!load_done)
      download_reset_cnt <= 8'd255;
    else if(load_done && download_reset_cnt != 0)
      download_reset_cnt <= download_reset_cnt - 8'd1;
  end

  // hold machine in reset until first download starts
  reg downloading = 0;
  reg init_reset = 1;
  always @(posedge clock) begin
    if (!downloading && flash_loader_data_ready) downloading <= 1'b1;
    if(downloading) init_reset <= 1'b0;
  end

  wire [15:0] sd_data_in;
  wire [15:0] sd_data_out;
  assign sdram_d = (!load_done ? !loader_write_mem : !memory_write) ? 16'hzzzz : sd_data_out;
  assign sd_data_in = sdram_d;

  reg loader_write_triggered = 1'b0;
  reg [7:0] loader_write_data_mem;
  reg [21:0] loader_addr_mem;
  reg loader_write_mem = 1'b0;

  sdram
  sdram_i
  (
   .sd_data_in(sd_data_in),
   .sd_data_out(sd_data_out),
   .sd_addr(sdram_a),
   .sd_dqm({sdram_dqm[1], sdram_dqm[0]}),
   .sd_cs(sdram_csn),
   .sd_ba(sdram_ba),
   .sd_we(sdram_wen),
   .sd_ras(sdram_rasn),
   .sd_cas(sdram_casn),
   // system interface
   .clk(clock_sdram_core),
   .clkref(nes_ce[1]),
   .init(!clock_locked),
   .we_out(memory_write),
   // cpu/chipset interface
   .addrA     	   (!load_done ? {3'b000, loader_addr_mem} : {3'b000, memory_addr_cpu}),
   .addrB          ({3'b000, memory_addr_ppu} ),

   .weA            (!load_done ?  loader_write_mem : memory_write_cpu),
   .weB            (memory_write_ppu),

   .dinA           (!load_done ? loader_write_data_mem : memory_dout_cpu),
   .dinB           (memory_dout_ppu),

   .oeA            (memory_read_cpu),
   .doutA          (memory_din_cpu ),

   .oeB            (memory_read_ppu),
   .doutB          (memory_din_ppu )
  );

  assign sdram_cke = 1'b1;
  assign sdram_clk = clock_sdram_chip;

  wire reset_nes = (!load_done || init_reset || download_reset || sys_reset) ;
  wire [1:0] nes_ce;

  reg last_joypad_clock;
  reg [7:0] joypad_bits;
  reg [7:0] buttons;

  reg [7:0] R_buttons;
  wire  joy_data, joy_strobe, joy_clock;
  generate
    if(use_external_nes_joypad)
    begin
      assign gp[0] = 1'bz;
      assign joy_data = gp[0];
      assign gp[1] = joy_strobe;
      assign gp[2] = joy_clock;
      always @(posedge clock)
      begin
        if (joy_strobe || (!joy_clock && last_joypad_clock) )
          joypad_bits[0] <= !joy_data;
        last_joypad_clock <= joy_clock;
      end
    end
    else // use_external_nes_joypad == 0: control using USB or onboard buttons
    begin
      always @(posedge clock)
      begin
        R_buttons <= {btn_right, btn_left, btn_down, btn_up, btn_start, btn_select, btn_b, btn_a};
        if (joy_strobe)
          joypad_bits <= R_buttons | usb_buttons;
        else
        begin
          if (!joy_clock && last_joypad_clock)
            joypad_bits <= {1'b0, joypad_bits[7:1]};
        end
        last_joypad_clock <= joy_clock;
      end
    end
  endgenerate

  wire [31:0] dbgadr;
  wire [2:0] dbgctr;

  NES
  nes_i
  (
   .clk(clock),
   .reset_nes(reset_nes),
   .sys_type(2'b00),
   .nes_div(nes_ce),
   .mapper_flags(mapper_flags),
   .sample(sample),
   .color(color),
   .joypad_strobe(joy_strobe),
   .joypad_clock(joy_clock),
   .joypad_data({3'b0, joypad_bits[0]}),
   .audio_channels(5'b11111),  // enable all channels
   .cpumem_addr(memory_addr_cpu),
   .cpumem_read(memory_read_cpu),
   .cpumem_din(memory_din_cpu),
   .cpumem_write(memory_write_cpu),
   .cpumem_dout(memory_dout_cpu),
   .ppumem_addr(memory_addr_ppu),
   .ppumem_read(memory_read_ppu),
   .ppumem_write(memory_write_ppu),
   .ppumem_din(memory_din_ppu),
   .ppumem_dout(memory_dout_ppu),
   .cycle(cycle),
   .scanline(scanline),
   .int_audio(1),
   .ext_audio(1)
  );

  wire blank;
  wire [7:0] r;
  wire [7:0] g;
  wire [7:0] b;
  wire vga_vs;
  wire vga_hs;

  vga
  vga_i
  (
    .I_CLK(clock),
    .I_CLK_VGA(clk_pixel),
    .I_COLOR(color),
    .I_HCNT(cycle),
    .I_VCNT(scanline),
    .O_HSYNC(vga_hs),
    .O_VSYNC(vga_vs),
    .O_BLANK(blank),
    .O_RED(r),
    .O_GREEN(g),
    .O_BLUE(b)
  );

  wire [7:0] osd_vga_r, osd_vga_g, osd_vga_b;
  wire osd_vga_hsync, osd_vga_vsync, osd_vga_blank;
  spi_osd
  #(
    .c_start_x(62), .c_start_y(80),
    .c_chars_x(64), .c_chars_y(20),
    .c_init_on(0),
    .c_transparency(C_osd_transparency),
    .c_char_file("osd.mem"),
    .c_font_file("font_bizcat8x16.mem")
  )
  spi_osd_inst
  (
    .clk_pixel(clk_pixel), .clk_pixel_ena(1),
    .i_r(r), .i_g(g), .i_b(b),
    .i_hsync(~vga_hs), .i_vsync(~vga_vs), .i_blank(blank),
    .i_csn(~wifi_gpio5), .i_sclk(wifi_gpio16), .i_mosi(sd_d[1]), // .o_miso(),
    .o_r(osd_vga_r), .o_g(osd_vga_g), .o_b(osd_vga_b),
    .o_hsync(osd_vga_hsync), .o_vsync(osd_vga_vsync), .o_blank(osd_vga_blank)
  );

  // VGA to digital video converter
  wire [1:0] tmds[3:0];
  vga2dvid
  #(
    .C_ddr(1'b1),
    .C_shift_clock_synchronizer(1'b0)
  )
  vga2dvid_instance
  (
    .clk_pixel(clk_pixel),
    .clk_shift(clk_shift),
    .in_red(osd_vga_r),
    .in_green(osd_vga_g),
    .in_blue(osd_vga_b),
    .in_hsync(osd_vga_hsync),
    .in_vsync(osd_vga_vsync),
    .in_blank(osd_vga_blank),
    .out_clock(tmds[3]),
    .out_red(tmds[2]),
    .out_green(tmds[1]),
    .out_blue(tmds[0])
  );

  // vendor specific DDR modules
  // convert SDR 2-bit input to DDR clocked 1-bit output (single-ended)
  ODDRX1F ddr_clock (.D0(tmds[3][0]), .D1(tmds[3][1]), .Q(gpdi_dp[3]), .SCLK(clk_shift), .RST(0));
  ODDRX1F ddr_red   (.D0(tmds[2][0]), .D1(tmds[2][1]), .Q(gpdi_dp[2]), .SCLK(clk_shift), .RST(0));
  ODDRX1F ddr_green (.D0(tmds[1][0]), .D1(tmds[1][1]), .Q(gpdi_dp[1]), .SCLK(clk_shift), .RST(0));
  ODDRX1F ddr_blue  (.D0(tmds[0][0]), .D1(tmds[0][1]), .Q(gpdi_dp[0]), .SCLK(clk_shift), .RST(0));

  wire [3:0] audio;
  generate
    if(C_audio==0)
      assign audio = sample[$bits(sample)-1:$bits(sample)-$bits(audio)];
    if(C_audio==1)
    begin
      wire dac1bit;
      sigma_delta_dac
      sigma_delta_dac_instance
      (
        .CLK(clock),
        .RESET(reset_nes),
        .DACin(sample),
        .DACout(dac1bit)
      );
      assign audio = {4{dac1bit}};
    end
    if(C_audio==2)
    begin
      wire dac1bit;
      sigma_delta_dac
      #(
        .MSBI(11)
      )
      sigma_delta_dac_instance
      (
        .CLK(clock),
        .RESET(reset_nes),
        .DACin(sample[11:0]),
        .DACout(dac1bit)
      );
      wire [$bits(audio)-1:0] dac0 = sample[$bits(sample)-1:$bits(sample)-$bits(audio)];
      wire [$bits(audio)-1:0] dac1 = sample[$bits(sample)-1:$bits(sample)-$bits(audio)] + 1;
      assign audio = dac1bit ? dac1 : dac0;
    end
  endgenerate
  assign audio_l = audio;
  assign audio_r = audio;
endmodule
