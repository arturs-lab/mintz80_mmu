module mintz80_mmu(clk,sysclk,reset,rd,wr,a07,a1513,data,mreq,iorq,ramen,romen,b14,b16,b17,beep);
	input clk;
	output sysclk;
	input reset;
	input rd;
	input wr;
	input [7:0]a07;
	input [15:13]a1513;
	inout [7:0] data;
	input mreq;
	input iorq;
	output romen;
	output ramen;
	output b14;
	output b16;
	output b17;
	output beep;

	wire romen;
	wire ramen;
	wire memmapwr;
	wire [2:0]memmap;
	wire ioe;
	wire [1:0]clkdivide;
	
	assign romen = (mreq || memmap[0]);	// memmap[0] low
	assign ramen = (mreq || ~memmap[0]);	// memmap[0] high, memmap[2] low
	assign b17=memmap[2];
	assign b16=memmap[1];
	assign b14=(memmap[0]==0) ? memmap[1] : a1513[14];

	// ioe equ $d0 - $df
	assign ioe = !iorq && a07[7] && a07[6] && ~a07[5] && a07[4];

	// memmap	equ $d8-df
	assign memmapwr = (!wr && ioe && a07[3]);
	assign memmaprd = (!rd && ioe && a07[3]);

	// select clock or beeper $d0-d1
	assign clk_or_beep = (ioe && ~a07[3] && ~a07[2] && ~a07[1] );
	// clkdivide_e	equ $d0
	assign clkdivide_e_wr = ( !wr && clk_or_beep && ~a07[0] );
	assign clkdivide_e_rd = ( !rd && clk_or_beep && ~a07[0] );
	// beep	equ $d1
	assign beep_rd = (!rd && clk_or_beep && a07[0]);	// unlocks memmap
	assign beep_wr = (!wr && clk_or_beep && a07[0]);	// triggers beep and locks memmap

	// select external IO $d4-d7
	assign extio = ~(ioe && ~a07[3] && a07[2] );
	
	reg beep;
	always@(posedge beep_wr)
		beep <= ~beep;
		
	clkgen clkgen(
		.clk (clk),
		.cpuclk (sysclk),
		.clkdivide (clkdivide[1:0])
	);
	
	// clkdivide	equ $d0
	clkdivide_r clkdivide_r(
		.reset (reset),
		.clkdivide_e_wr (clkdivide_e_wr),
		.clkdivide (clkdivide[1:0]),
		.data (data[1:0])
	);

	dio dio(
		.data (data),
		.memmaprd (memmaprd),
		.memmap (memmap[2:0]),
//		.clkdivide_e_rd (clkdivide_e_rd),
//		.clkdivide (clkdivide[1:0])
	);
	
	// memmap	equ $d8
	memmapr memmapr(
		.reset (reset),
		.memmapwr (memmapwr),
		.adr (a07[2:0]),
		.data (data[2:0]),
		.outsel (a1513[15:13]),
		.out (memmap[2:0]),
		.memmaprd (memmaprd),
	);
		
endmodule

module clkgen(clk,cpuclk,clkdivide);
	input clk;
	output cpuclk;
	input [1:0]clkdivide;
	
	reg [3:0]cpucnt;
	wire cpuclk;
	
	always @(posedge clk) cpucnt <= cpucnt + 4'd01;
	
	assign cpuclk = (clkdivide == 2'd3) ? cpucnt[3] : (clkdivide == 2'd2) ? cpucnt[2] : (clkdivide == 2'd1) ? cpucnt[1] : cpucnt[0];

endmodule

module clkdivide_r(reset,clkdivide_e_wr,clkdivide,data);
	input reset;
	input clkdivide_e_wr;
	output [1:0]clkdivide;
	input [1:0]data;
	
	reg [1:0]clkdivide;

	initial clkdivide <= 2'h01;
	
	always @(posedge clkdivide_e_wr,negedge reset) begin
		if (reset == 0) begin
			clkdivide <= 2'h01;
		end
		else begin
			clkdivide <= data[1:0];
		end
	end
	
endmodule


module dio(data,memmaprd,memmap);
	output [7:0]data;
	input memmaprd;
	input [2:0]memmap;
//	input clkdivide_e_rd;
//	input [1:0]clkdivide;
	
//	assign data = (clkdivide_e_rd) ? {{7'd0,clkdivide}} : (memmaprd) ? {{6'd0,memmap}} : 8'bZ;
	
	assign data = (memmaprd) ? {{5'd0,memmap}} : 8'bZ;

endmodule

module memmapr(reset,memmapwr,adr,data,out,outsel,out,memmaprd);
	input reset;
	input memmapwr;
	input [2:0]adr;
	input [2:0]data;
	output [2:0]out;
	input [2:0]outsel;
	input memmaprd;
	
	reg [2:0]memmap [7:0];
	
	assign out = (memmaprd)? memmap[adr] : memmap[outsel];

	always @(negedge reset, posedge memmapwr) begin
		if (reset == 0) begin
			memmap[3'd0] <= 3'd0;
			memmap[3'd1] <= 3'd1;
			memmap[3'd2] <= 3'd1;
			memmap[3'd3] <= 3'd1;
			memmap[3'd4] <= 3'd1;
			memmap[3'd5] <= 3'd1;
			memmap[3'd6] <= 3'd1;
			memmap[3'd7] <= 3'd1;
		end
		else begin
			memmap[adr] <= data;
		end
	end
		
endmodule

