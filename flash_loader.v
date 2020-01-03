/*
The virtual NES cartridge
At the moment this stores the entire cartridge
in SPRAM, in the future it could stream data from
SQI flash, which is more than fast enough
*/

module flash_loader(
  input clock,
  input reset,
  
  input reload,
  input [3:0] index,
  
  output cart_ready,
  output reg [31:0] flags_out,

  //Flash load interface
  output flash_csn,
  output flash_sck,
  output flash_mosi,
  input flash_miso,

  output [7:0] load_write_data,
  output [21:0] load_address,
  output load_wren
);


localparam [16:0] END_ADDR = 17'h10000;
`ifndef SIM
localparam [23:0] FLASH_BEGIN_ADDR = 24'h200000;
`else
localparam [23:0] FLASH_BEGIN_ADDR = 24'h000000;
`endif


reg load_done;
initial load_done = 1'b0;

assign cart_ready = load_done;

reg [16:0] load_addr;
reg [21:0] nes_load_address;
assign load_address = nes_load_address;

wire flashmem_valid = !load_done;
wire flashmem_ready;
assign load_wren = flashmem_ready && (load_addr < END_ADDR);
wire [23:0] flashmem_addr = (FLASH_BEGIN_ADDR + (index_lat << 18)) | {load_addr};
reg [3:0] index_lat;
reg load_done_pre;

reg [2:0] flags_ctr = 0;
reg [7:0] wait_ctr = 0;

// Flash memory load interface
always @(posedge clock) 
begin
  if (reset == 1'b1) begin
    load_done_pre <= 1'b0;
    load_done <= 1'b0;
    load_addr <= 17'h0000;
    flags_out <= 32'h00000000;
    wait_ctr <= 8'h00;
    index_lat <= 4'h0;
    flags_ctr <= 3'b0;
    nes_load_address <= 22'b0;
  end else begin
    if (reload == 1'b1) begin
      load_done_pre <= 1'b0;
      load_done <= 1'b0;
      load_addr <= 17'h0000;
      flags_out <= 32'h00000000;
      wait_ctr <= 8'h00;
      flags_ctr <= 3'b0;
      index_lat <= index;
      nes_load_address <= 22'b0;
    end else begin
      if(!load_done_pre) begin
        if (flashmem_ready == 1'b1) begin
          if (load_addr >= END_ADDR) begin
            if (flags_ctr < 3'd4) begin
              flags_ctr <= flags_ctr + 3'd1;
              load_addr <= load_addr + 1'b1;
            end else 
              load_done_pre <= 1'b1;

            flags_ctr <= flags_ctr + 2'd1;
            case (flags_ctr)
              0: flags_out[7:0] <= load_write_data;
              1: flags_out[15:8] <= load_write_data;
              2: flags_out[23:16] <= load_write_data;
              3: flags_out[31:24] <= load_write_data;
            endcase

          end else 
            nes_load_address <= nes_load_address + 1'b1;
            load_addr <= load_addr + 1'b1;
            if (nes_load_address == 22'h8000) begin
              nes_load_address <= 22'b10_0000_0000_0000_0000_0000; 
            end
        end
      end else begin
        if (wait_ctr < 8'hFF)
          wait_ctr <= wait_ctr + 1;
        else
          load_done <= 1'b1;
      end
    end
  end
end

icosoc_flashmem flash_i (
	.clk(clock),
  .reset(reset),
  .valid(flashmem_valid),
  .ready(flashmem_ready),
  .addr(flashmem_addr),
  .rdata(load_write_data),

	.spi_cs(flash_csn),
	.spi_sclk(flash_sck),
	.spi_mosi(flash_mosi),
	.spi_miso(flash_miso)
);

endmodule
