module framebuffer(
    input clock_a,
    input [5:0] data_a,
    input [15:0] address_a,
    input wren_a,
    //
    input clock_b,
    input [15:0] address_b,
    output reg [5:0]  q_b);

(* keep *) reg [5:0] mem[61440];

always @(posedge clock_a) begin
    if (wren_a)
        mem[address_a] <= data_a;
end

always @(posedge clock_b) begin
    q_b <= mem[address_b];
end


endmodule
