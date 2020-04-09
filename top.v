module top
#(
  parameter use_external_nes_joypad=0,
  parameter C_audio=2, // 0: direct 4-bit, 1: 1-bit DAC, 2: 4-bit DAC
  parameter C_usb_speed=0,  // 0:6 MHz USB1.0, 1:48 MHz USB1.1, -1: USB disabled,
  // xbox360 : C_report_bytes=20, C_report_bytes_strict=1
  // darfon  : C_report_bytes= 8, C_report_bytes_strict=1
  parameter C_report_bytes=8, // 8:usual joystick, 20:xbox360
  parameter C_report_bytes_strict=1, // 0:when report length is variable/unknown
  parameter C_autofire_hz=10, // joystick trigger and bumper
  parameter C_osd_usb=1, // 0:OSD onboard BTN's 1:OSD USB joystick
  // choose one: C_flash_loader or C_esp32_loader
  parameter C_flash_loader=0, // fujprog -j flash -f 0x200000 100in1.img
  parameter C_esp32_loader=1 // usage: import nes # for OSD press together A B SELECT START or all 4 directions
)
(
  input  clk_25mhz,
`ifdef SIM
  output flash_sck,
`endif
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


  // passthru to ESP32 micropython serial console
  assign wifi_rxd = ftdi_txd;
  assign ftdi_rxd = wifi_txd;

  assign sd_d[3] = 1'bz; // FPGA pin pullup sets SD card inactive at SPI bus
  //assign sd_d[2] = 1'bz;

  wire clk_125MHz, clk_25MHz; // video
  wire clk_48MHz, clk_6MHz; // usb
  wire dvi_clock_locked;
  clk_25_125_48_6_25
  clk_dvi_usb_inst
  (
    .clk25_i(clk_25mhz),
    .clk125_o(clk_125MHz),
    .clk48_o(clk_48MHz),
    .clk6_o(clk_6MHz),
    .clk25_o(clk_25MHz),
    .locked(dvi_clock_locked)
  );
  wire clk_shift = clk_125MHz;
  wire clk_pixel = clk_25MHz;

  wire clock;
  wire clock_locked;
  wire clock_sdram;
  clocks
  clocks_inst
  (
    .clock25(clk_25mhz),
    .clock21(clock),
    .clock85(clock_sdram),
    .clock_locked(clock_locked)
  );

`ifndef SIM
  wire flash_sck;
  wire tristate = 1'b0;
  USRMCLK u1 (.USRMCLKI(flash_sck), .USRMCLKTS(tristate));
`endif

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

  wire [8:0] cycle;
  wire [8:0] scanline;
  wire [5:0] color;
  wire [15:0] sample;

  wire load_done;
  wire [21:0] memory_addr;
  wire memory_read_cpu, memory_read_ppu;
  wire memory_write;
  wire [7:0] memory_din_cpu, memory_din_ppu;
  wire [7:0] memory_dout;
  
  wire [31:0] mapper_flags;

  // assign led = !load_done;
  
  wire reload = 1'b0;

  wire [7:0] flash_loader_data_out;
  wire [21:0] game_loader_address;
  reg [21:0] load_address_reg;
  wire [7:0] game_loader_mem;
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
    wire [31:0] spi_addr;
    wire spi_rd;
    reg  [7:0] R_spi_data_in;
    wire spi_wr;
    reg R_spi_wr;
    spirw_slave_v
    #(
      .c_addr_bits($bits(spi_addr)),
      .c_sclk_capable_pin(1'b0)
    )
    spirw_slave_inst
    (
      .clk(clock),
      .csn(~wifi_gpio5),
      .sclk(wifi_gpio16),
      .mosi(sd_d[1]), // wifi_gpio4
      .miso(sd_d[2]), // wifi_gpio12
      .rd(spi_rd),
      .wr(spi_wr),
      .addr(spi_addr),
      .data_in(R_spi_data_in), // R_spi_data_in used to read BTN state
      .data_out(flash_loader_data_out)
    );
    wire flash_loader_data_ready = spi_wr & ~R_spi_wr;
    reg R_sys_reset;
    always @(posedge clock)
    begin
      R_spi_wr <= spi_wr;
      if(spi_wr == 1'b1 && spi_addr[31:24] == 8'hFF)
        R_sys_reset <= flash_loader_data_out[0];
    end
    assign sys_reset = R_sys_reset;
    // SPI read: IRQ flags and button state
    reg [7:0] R_btn, R_btn_latch;
    reg R_btn_irq;
    always @(posedge clock)
      if(spi_rd)
      begin
        if(spi_addr[31:24] == 8'h00)
          R_spi_data_in <= {R_btn_irq,7'd0};
        else
          R_spi_data_in <= {1'b0,R_btn};
      end
    // IRQ controller tracks joystick state
    reg R_spi_rd;
    reg [19:0] R_btn_debounce;
    always @(posedge clock)
    begin
      R_spi_rd <= spi_rd;
      if(spi_rd == 1'b0 && R_spi_rd == 1'b1 && spi_addr[31:24] == 8'h00)
        R_btn_irq <= 1'b0;
      else // BTN state is read from 0xFExxxxxx
      begin
        if(C_osd_usb)
          R_btn_latch <=
          {
            1'b0,
            usb_buttons[7], // 6 right
            usb_buttons[6], // 5 left
            usb_buttons[5], // 4 down
            usb_buttons[4], // 3 up
            1'b0,           // 2 B
            1'b0,           // 1 A
            1'b1            // 0 start
          };
        else
          R_btn_latch <= {1'b0,btn};
        if(R_btn != R_btn_latch && R_btn_debounce[$bits(R_btn_debounce)-1] == 1 && R_btn_irq == 0)
        begin
          R_btn_irq <= 1'b1;
          R_btn_debounce <= 0;
          R_btn <= R_btn_latch;
        end
        else
          if(R_btn_debounce[$bits(R_btn_debounce)-1] == 1'b0)
            R_btn_debounce <= R_btn_debounce + 1;
      end
    end
    assign wifi_gpio0 = ~R_btn_irq; // interrupt line, active on falling edge
    //assign led = {R_btn_irq,btn};
    //assign led = R_btn_latch;
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
    .clk(clock_sdram),
    .clkref(nes_ce[1]),
    .init(sys_reset),
    // cpu/chipset interface
    .addr(!load_done ? {3'b000, loader_addr_mem} : {3'b000, memory_addr}),
    .we(load_done ? memory_write : loader_write_mem),
    .din(!load_done ? loader_write_data_mem : memory_dout),
    .oeA(memory_read_cpu),
    .doutA(memory_din_cpu),
    .oeB(memory_read_ppu),
    .doutB(memory_din_ppu)
  );

  assign sdram_cke = 1'b1;
  assign sdram_clk = clock_sdram;

  wire reset_nes = !load_done || sys_reset;
  reg [1:0] nes_ce = 0;
  wire run_nes = (nes_ce == 3);	// keep running even when reset, so that the reset can actually do its job!

  // NES is clocked at every 4th cycle.
  always @(posedge clock)
    nes_ce <= nes_ce + 1;

  // select button is not functional
  // as we don't have any onboard buttons left on the board
  wire btn_select = 1'b0;

  reg last_joypad_clock;
  reg [7:0] joypad_bits;
  reg [7:0] buttons;

  reg [6:0] R_buttons;
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
    clock, reset_nes, run_nes,
    mapper_flags,
    sample, color,
    joy_strobe, joy_clock, {3'b0, joypad_bits[0]},
    5'b11111,  // enable all channels
    memory_addr,
    memory_read_cpu, memory_din_cpu,
    memory_read_ppu, memory_din_ppu,
    memory_write, memory_dout,
    cycle, scanline,
    dbgadr,
    dbgctr
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
    .c_char_file("osd.mem"),
    .c_font_file("font_vga.mem")
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
        .CEN(run_nes),
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
        .CEN(run_nes),
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
