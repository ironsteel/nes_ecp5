`timescale 10 ns/ 1 ps 

module testbench;
  wire CLKIN;
  reg clk25 = 0;
  always #2 clk25 = ~clk25;

  reg reset = 1'b1;
  wire SPI_FLASH_CS ;
  wire SPI_FLASH_MISO;
  wire SPI_FLASH_MOSI;
  wire SPI_FLASH_SCLK;
  wire [7:0] audio_out;

  top nes(  
    .clk25(clk25),
    .reset_btn(reset),
    .flash_sck(SPI_FLASH_SCLK),
    .flash_csn(SPI_FLASH_CS),
    .flash_mosi(SPI_FLASH_MOSI),
    .flash_miso(SPI_FLASH_MISO),
    .scanlines(1'b0),
    .mode(1'b0),
    .overscan(1'b0),
    .pallete(1'b0),
    .audio_sample(audio_out)
  );

  sim_spiflash #(
    .MEM_INIT_FILE("games_8.hex")
  ) spiflash (
    .SPI_FLASH_CS(SPI_FLASH_CS),
    .SPI_FLASH_MOSI(SPI_FLASH_MOSI),
    .SPI_FLASH_MISO(SPI_FLASH_MISO),
    .SPI_FLASH_SCLK(SPI_FLASH_SCLK)
  );

  event appimage_ready;

  initial begin
    if ($test$plusargs("vcd")) begin
      $dumpfile("testbench.vcd");
      $dumpvars(0, testbench);
    end
  end

  initial begin
    repeat (2) @(posedge clk25) begin
      reset <= !reset;
    end

    repeat (100000) @(posedge clk25);
    $display("-- Simulation finished --");
    $finish;
  end
endmodule

