// Module reads bytes and writes to proper address in ram.
// Done is asserted when the whole game is loaded.
// This parses iNES headers too.
module game_loader(
	input			clk,
	input			reset,
	input [7:0]		indata,
	input			indata_clk,
	output reg [21:0]	mem_addr,
	output [7:0]		mem_data,
	output			mem_write,
	output [31:0]		mapper_flags,
	output reg		done);
	
	reg [ 1:0] state = 0;
	reg [ 7:0] prgsize;
	reg [ 3:0] ctr;
	reg [ 7:0] ines[0:15];	// 16 bytes of iNES header
	reg [21:0] bytes_left;
	
//	assign error = (state == 3);
	assign mem_data = indata;
	assign mem_write = (bytes_left != 0) && (state == 1 || state == 2) && indata_clk;
	
	wire [2:0] prg_size =	ines[4] <= 1 ? 0 :
				ines[4] <= 2 ? 1 : 
				ines[4] <= 4 ? 2 : 
				ines[4] <= 8 ? 3 : 
				ines[4] <= 16 ? 4 : 
				ines[4] <= 32 ? 5 : 
				ines[4] <= 64 ? 6 : 7;

	wire [2:0] chr_size = 	ines[5] <= 1 ? 0 : 
				ines[5] <= 2 ? 1 : 
				ines[5] <= 4 ? 2 : 
				ines[5] <= 8 ? 3 : 
				ines[5] <= 16 ? 4 : 
				ines[5] <= 32 ? 5 : 
				ines[5] <= 64 ? 6 : 7;
	
	wire has_chr_ram = (ines[5] == 0);
	assign mapper_flags = {16'b0, has_chr_ram, ines[6][0], chr_size, prg_size, ines[7][7:4], ines[6][7:4]};
	
	always @(posedge clk) begin
		if (reset) begin
			state <= 0;
			done <= 0;
			ctr <= 0;
			mem_addr <= 0;	// Address for PRG
		end else begin
			case(state)
			// Read 16 bytes of ines header
			0: if (indata_clk) begin
				ctr <= ctr + 1;
				ines[ctr] <= indata;
				bytes_left <= {ines[4], 14'b0};
				if (ctr == 4'b1111)
					state <= (ines[0] == 8'h4E) && (ines[1] == 8'h45) && (ines[2] == 8'h53) && (ines[3] == 8'h1A) && !ines[6][2] && !ines[6][3] ? 1 : 3;
				end
			1, 2: begin // Read the next |bytes_left| bytes into |mem_addr|
				if (bytes_left != 0) begin
					if (indata_clk) begin
						bytes_left <= bytes_left - 1;
						mem_addr <= mem_addr + 1;
					end
				end else if (state == 1) begin
					state <= 2;
					mem_addr <= 22'b10_0000_0000_0000_0000_0000; // Address for CHR
					bytes_left <= {1'b0, ines[5], 13'b0};
				end else if (state == 2) begin
				done <= 1;
				end
				end
			endcase
		end
	end
endmodule
