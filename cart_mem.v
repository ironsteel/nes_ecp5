/*
The virtual NES cartridge
At the moment this stores the entire cartridge
in SPRAM, in the future it could stream data from
SQI flash, which is more than fast enough
*/

module cart_mem(
  input clock,
  input reset,
  
  input reload,
  input [3:0] index,

  output cart_ready,
  
  //Flash load interface
  output flash_csn,
  output flash_sck,
  output flash_mosi,
  input flash_miso

);

    
localparam [18:0] END_ADDR = 19'h40000;


reg [18:0] load_addr; 
reg load_done;
initial load_done = 1'b0;

assign cart_ready = !load_done;

wire flashmem_valid = !load_done;
wire flashmem_ready;
wire [23:0] flashmem_addr = (24'h200000 + (index_lat << 18)) | {load_addr, 1'b0};
reg [3:0] index_lat;
reg load_done_pre;


reg [8:0] wait_ctr;
// Flash memory load interface
always @(posedge clock) 
begin
  if (reset == 1'b1) begin
    load_done_pre <= 1'b0;
    load_done <= 1'b0;
    load_addr <= 19'h00000;
    wait_ctr <= 9'h000;
    index_lat <= 4'h0;
  end else begin
    if (reload == 1'b1) begin
      load_done_pre <= 1'b0;
      load_done <= 1'b0;
      load_addr <= 19'h0000;
      wait_ctr <= 9'h000;
      index_lat <= index;
    end else begin
      if(!load_done_pre) begin
        if (flashmem_ready == 1'b1) begin
          if (load_addr == END_ADDR) begin
	    load_addr <= load_addr + 1'b1;
          end else if (load_addr == END_ADDR + 1'b1) begin
            load_done_pre <= 1'b1;
          end else begin
	    load_addr <= load_addr + 1'b1;
          end;
        end
      end else begin
        if (wait_ctr < 9'h0FF)
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
