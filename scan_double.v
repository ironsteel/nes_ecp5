module scan_double(input clk,
            input [14:0] inputpixel,
            input reset_frame,
            input reset_line,
            input [9:0] read_x,
            output reg [14:0] outpixel);
reg [1:0] frac;
reg [14:0] linebuf[0:255];
reg [8:0] write_x;

always @(posedge clk)
begin
  if(reset_line)
  begin
    frac <= 2'b00;
    write_x <= 9'd0;
  end else begin
    frac <= frac + 1;
    if (frac == 2)
      if (write_x < 256)
        write_x <= write_x + 1;
  end
end

wire write_en = ((frac == 2) && (write_x < 256)) ? 1'b1 : 1'b0;

always @(posedge clk)
begin
  outpixel <= linebuf[read_x[8:1]];
  if(write_en)
    linebuf[write_x[7:0]] <= inputpixel;
end


endmodule
