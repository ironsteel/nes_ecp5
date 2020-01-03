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
  output        VGA_HS,
  output        VGA_VS,
  output [3:0]  VGA_R,
  output [3:0]  VGA_G,
  output [3:0]  VGA_B,

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

  input reset_btn,

  input joy_data,
  output joy_strobe,
  output joy_clock,

  input scanlines,
  input mode,
  input overscan,
  input pallete,
  output [7:0] audio_sample
);


  wire clock;
  wire clock_locked;
  wire clock_sdram;

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

  wire sys_reset = !clock_locked || !reset_btn;

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

  wire [7:0] load_write_data;
  wire [21:0] load_address;
  reg [21:0] load_address_reg;
  wire load_wren;
  flash_loader flash_load_i (
    .clock(clock),
    .reset(sys_reset),
    .reload(reload),
    .index({4'b0000}),
    .cart_ready(load_done),
    .flags_out(mapper_flags),
    .load_write_data(load_write_data),
    .load_address(load_address),
    .load_wren(load_wren),
    
    //Flash load interface
    .flash_csn(flash_csn),
    .flash_sck(flash_sck),
    .flash_mosi(flash_mosi),
    .flash_miso(flash_miso)
  );

  TRELLIS_IO #(.DIR("BIDIR")) 
    sdio_tristate[15:0] (
      .B(sdram_d),
      .I(sd_data_out),
      .O(sd_data_in),
      .T(!load_done ? !loader_write_mem : !memory_write));

  wire [15:0] sd_data_in;
  wire  [15:0] sd_data_out;

  reg loader_write_triggered = 1'b1;
  reg [7:0] loader_write_data_mem;
  reg [21:0] loader_addr_mem;
  reg loader_write_mem = 1'b0;

  sdram U8(
    // interface to the MT48LC16M16 chip
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
    .din(!load_done ? load_write_data : memory_dout),
    .oeA(memory_read_cpu),
    .doutA(memory_din_cpu),
    .oeB(memory_read_ppu),
    .doutB(memory_din_ppu));

	// loader_write -> clock when data available
  always @(posedge clock) begin
    if(load_wren) begin
      loader_write_triggered	<= 1'b1;
      loader_addr_mem		<= load_address;
      loader_write_data_mem	<= load_write_data;
    end

    if(nes_ce == 3) begin
      loader_write_mem <= loader_write_triggered;
      if(loader_write_triggered)
        loader_write_triggered <= 1'b0;
    end
  end

  assign sdram_cke = 1'b1;
  assign sdram_clk = clock_sdram;

  wire reset_nes = !load_done || sys_reset;
  reg [1:0] nes_ce = 0;
  wire run_nes = (nes_ce == 3);	// keep running even when reset, so that the reset can actually do its job!

  // NES is clocked at every 4th cycle.
  always @(posedge clock)
    nes_ce <= nes_ce + 1;

  reg joy_data_sync = 0;
  reg last_joypad_clock;

  always @(posedge clock) begin
    if (joy_strobe) begin
      joy_data_sync <= joy_data;
    end
    if (!joy_clock && last_joypad_clock) begin
      joy_data_sync <= joy_data;
    end
    last_joypad_clock <= joy_clock;
  end

  wire [31:0] dbgadr;
  wire [2:0] dbgctr;

  NES nes(clock, reset_nes, run_nes,
    mapper_flags,
    sample, color,
    joy_strobe, joy_clock, {3'b0, !joy_data_sync},
    5'b11111,  // enable all channels
    memory_addr,
    memory_read_cpu, memory_din_cpu,
    memory_read_ppu, memory_din_ppu,
    memory_write, memory_dout,
    cycle, scanline,
    dbgadr,
    dbgctr);

  video video (
    .clk(clock),
    .color(color),
    .count_v(scanline),
    .count_h(cycle),
    .mode(mode),
    .smoothing(1'b0),
    .scanlines(scanlines),
    .overscan(overscan),
    .palette(pallete),
    
    .VGA_HS(VGA_HS),
    .VGA_VS(VGA_VS),
    .VGA_R(VGA_R),
    .VGA_G(VGA_G),
    .VGA_B(VGA_B)
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

endmodule
