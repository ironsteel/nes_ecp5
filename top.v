module top(
	input clk,
	output flash_csn,
	output flash_mosi,
	input flash_miso,

	output led,
	// VGA
	output         VGA_HS, // VGA H_SYNC
	output         VGA_VS, // VGA V_SYNC
	output [ 2:0]  VGA_R, // VGA Red[3:0]
	output [ 2:0]  VGA_G, // VGA Green[3:0]
	output [ 2:0]  VGA_B, // VGA Blue[3:0]

	input btn,

	input joy_data,
	output joy_strobe,
	output joy_clock,

	input scanlines,
	input mode,
	input overscan,
	input pallete
);


wire clock;
wire locked;

wire flash_sck;

wire tristate = 1'b0;

USRMCLK u1 (.USRMCLKI(flash_sck), .USRMCLKTS(tristate));

wire clock1;
pll pll_i(
	.clkin(clk),
	.clkout0(clock1),
	.locked(locked_pre)
);

  wire scandoubler_disable;

  reg clock_locked;
  wire locked_pre;
  always @(posedge clock)
    clock_locked <= locked_pre;

  wire [8:0] cycle;
  wire [8:0] scanline;
  wire [15:0] sample;
  wire [5:0] color;
  
  wire load_done;
  wire [21:0] memory_addr;
  wire memory_read_cpu, memory_read_ppu;
  wire memory_write;
  wire [7:0] memory_din_cpu, memory_din_ppu;
  wire [7:0] memory_dout;
  
  wire [31:0] mapper_flags;

  assign led = !load_done;
  
  wire sys_reset = !clock_locked;
  wire reload = 1'b0;

  wire run_nes_g;

  assign run_nes_g = run_nes;

  DCCA gb_clock1(
	  .CLKI(clock1),
	  .CE(1),
	  .CLKO(clock)
  );

  always @(posedge clock) begin
	  reload <= !btn;
  end

  
  main_mem mem (
    .clock(clock),
    .reset(sys_reset),
    .reload(reload),
    .index({4'b0000}),
    .load_done(load_done),
    .flags_out(mapper_flags),
    //NES interface
    .mem_addr(memory_addr),
    .mem_rd_cpu(memory_read_cpu),
    .mem_rd_ppu(memory_read_ppu),
    .mem_wr(memory_write),
    .mem_q_cpu(memory_din_cpu),
    .mem_q_ppu(memory_din_ppu),
    .mem_d(memory_dout),
    
    //Flash load interface
    .flash_csn(flash_csn),
    .flash_sck(flash_sck),
    .flash_mosi(flash_mosi),
    .flash_miso(flash_miso)
  );

  wire reset_nes = !load_done || sys_reset;
  reg [1:0] nes_ce;
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


  NES nes(clock, reset_nes, run_nes_g,
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

  assign VGA_R[0] = r[3];
  assign VGA_R[1] = r[2];
  assign VGA_G[2] = r[1];
  assign VGA_G[0] = g[3];
  assign VGA_G[1] = g[2];
  assign VGA_R[2] = g[1];
  assign VGA_B[0] = b[3];
  assign VGA_B[1] = b[2];
  assign VGA_B[2] = b[1];

wire [3:0] r;
wire [3:0] g;
wire [3:0] b;

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
	.VGA_R(r),
	.VGA_G(g),
	.VGA_B(b)
	
);
endmodule
