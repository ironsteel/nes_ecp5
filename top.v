module top(
  input clk25,
`ifdef SIM
  output flash_sck,
`endif
  output flash_csn,
  output flash_mosi,
  input flash_miso,

  output led,
  // VGA
  output        VGA_CLOCK,
  output        VGA_HS,
  output        VGA_VS,
  output [7:0]  VGA_R,
  // DVI out
  output [3:0] gpdi_dp, gpdi_dn,

  output sdram_csn,       // chip select
  output sdram_clk,       // clock to SDRAM
  output sdram_cke,       // clock enable to SDRAM
  output sdram_rasn,      // SDRAM RAS
  output sdram_casn,      // SDRAM CAS
  output sdram_wen,       // SDRAM write-enable
  output [12:0] sdram_a,  // SDRAM address bus
  output [1:0] sdram_ba,  // SDRAM bank-address
  output [1:0] sdram_dqm, // byte select
  inout [15:0] sdram_d,   // data bus to/from SDRAM


  input use_external_nes_joypad,

  input joy_data,
  output joy_strobe,
  output joy_clock,

  input btn_a,
  input btn_b,
  input btn_up,
  input btn_down,
  input btn_left,
  input btn_right,
  input btn_start,

  output [7:0] audio_sample
);


  wire clock;
  wire clock_locked;
  wire clock_sdram;
  wire clk_shift;
  wire dvi_clock_locked;

  pll_dvi pll_dvi_i(
    .clkin(clk25),
    .clkout0(clk_shift),
    .locked(dvi_clock_locked)
  );

  clocks clocks_i(
    .clock25(clk25),
    .clock21(clock),
    .clock85(clock_sdram),
    .clock_locked(clock_locked)
  );

`ifndef SIM
  wire flash_sck;
  wire tristate = 1'b0;
  USRMCLK u1 (.USRMCLKI(flash_sck), .USRMCLKTS(tristate));
`endif

  wire sys_reset = !clock_locked;

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

  assign led = !load_done;
  
  reg reload = 1'b0;

  wire [7:0] flash_loader_data_out;
  wire [21:0] game_loader_address;
  reg [21:0] load_address_reg;
  wire [7:0] game_loader_mem;
  wire flash_loader_data_ready;
  wire loader_write;

  flash_loader flash_load_i (
    .clock(clock),
    .reset(sys_reset),
    .reload(reload),
    .index({4'b0000}),
    .load_write_data(flash_loader_data_out),
    .data_valid(flash_loader_data_ready),
    
    //Flash load interface
    .flash_csn(flash_csn),
    .flash_sck(flash_sck),
    .flash_mosi(flash_mosi),
    .flash_miso(flash_miso)
  );

  game_loader game_loader_i(
    .clk(clock),
    .reset(sys_reset),
    .indata(flash_loader_data_out),
    .indata_clk(flash_loader_data_ready),
    .mem_addr(game_loader_address),
    .mem_data(game_loader_mem),
    .mem_write(loader_write),
    .mapper_flags(mapper_flags),
    .done(load_done));

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
  TRELLIS_IO #(.DIR("BIDIR")) 
    sdio_tristate[15:0] (
      .B(sdram_d),
      .I(sd_data_out),
      .O(sd_data_in),
      .T(!load_done ? !loader_write_mem : !memory_write));


  reg loader_write_triggered = 1'b0;
  reg [7:0] loader_write_data_mem;
  reg [21:0] loader_addr_mem;
  reg loader_write_mem = 1'b0;

  sdram U8(
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
    .doutB(memory_din_ppu));


  assign sdram_cke = 1'b1;
  assign sdram_clk = clock_sdram;

  wire reset_nes = !load_done || sys_reset;
  reg [1:0] nes_ce = 0;
  wire run_nes = (nes_ce == 3);	// keep running even when reset, so that the reset can actually do its job!

  // NES is clocked at every 4th cycle.
  always @(posedge clock)
    nes_ce <= nes_ce + 1;

  reg last_joypad_clock;
  reg [7:0] buttons;
  reg [7:0] joypad_bits;

  // select button is not functional
  // as we don't have any onboard buttons left on the board
  wire btn_select = 1'b0;

  always @(posedge clock) begin
    buttons <= {btn_right, btn_left, btn_down, btn_up, !btn_start, btn_select, btn_b, btn_a};
    if (joy_strobe) begin
      if (use_external_nes_joypad)
        joypad_bits[0] <= !joy_data;
      else
        joypad_bits <= buttons;
    end
    if (!joy_clock && last_joypad_clock) begin
      if (use_external_nes_joypad)
        joypad_bits[0] <= !joy_data;
      else
        joypad_bits <= {1'b0, joypad_bits[7:1]};
    end
    last_joypad_clock <= joy_clock;
  end

  wire [31:0] dbgadr;
  wire [2:0] dbgctr;

  NES nes(clock, reset_nes, run_nes,
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
    dbgctr);

  wire blank;
  wire [7:0] r;
  wire [7:0] g;
  wire [7:0] b;
  wire vga_vs;
  wire vga_hs;

reg vidclk_en;
always @(posedge clock) vidclk_en <= ~vidclk_en;
  video video (
	.clk(clock),
	.color(color),
	.count_v(scanline),
	.count_h(cycle),
  .pal_video(1'b0),
	.overscan(1'b1),
	.palette(1'b0),

	.sync_h(VGA_HS),
	.sync_v(VGA_VS),
	.r(VGA_R),
	.g(VGA_G),
	.b(VGA_B)
);
  assign audio_sample[7:0] = {8{audio}};
  wire audio;
  sigma_delta_dac sigma_delta_dac(
    .DACout(audio),
    .DACin(sample),
    .CLK(clock),
    .RESET(reset_nes),
    .CEN(run_nes)
  );
  assign VGA_CLOCK = vidclk_en;

endmodule
