module mintz80_mmu(clk,sysclk,reset,rd,wr,a07,a1513,data,mreq,iorq,ramen,romen,b14,b16,beep,extio);
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
	output beep;
	output extio;

	wire romen;
	wire ramen;
	wire memmapwr;
	wire [1:0]banksel;
	wire ioe;
	wire [5:0]clkdivide;
	wire [1:0]memmapdta;
	
	reg memmaplock;
	assign romen = (mreq || banksel[0]);	// banksel[0] low
	assign ramen = (mreq || ~banksel[0]);	// banksel[0] high
	assign b16=banksel[1];
	assign b14=(banksel[0]==0) ? banksel[1] : a1513[14];

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
		
	always@(posedge beep_wr,posedge beep_rd, negedge reset) begin
		if (reset == 0) begin
			memmaplock <= 0;
		end else if ( beep_wr == 1 ) begin
			memmaplock <= 0;
		end else if ( beep_rd == 1 ) 	
			memmaplock <= 1;
	end

	clkgen clkgen(
		.clk (clk),
		.cpuclk (sysclk),
		.clkdivide (clkdivide[5:0])
	);
	
	// clkdivide	equ $d0
	clkdivide_r clkdivide_r(
		.reset (reset),
		.clkdivide_e_wr (clkdivide_e_wr),
		.clkdivide (clkdivide[5:0]),
		.data (data[5:0])
	);
	
	dio dio(
		.data (data),
		.memmaprd (memmaprd),
		.memmapdta (memmapdta[1:0]),
		.clkdivide_e_rd (clkdivide_e_rd),
		.clkdivide (clkdivide[5:0])
	);
	
	// memmap	equ $d8
	memmap memmap(
		.reset (reset),
		.memmapwr (memmapwr),
		.memmapdta (memmapdta[1:0]),
		.adr (a07[2:0]),
		.data (data[1:0]),
		.outsel (a1513[15:13]),
		.out (banksel[1:0]),
		.memmaplock (memmaplock)
	);
		
endmodule

module clkgen(clk,cpuclk,clkdivide);
	input clk;
	output cpuclk;
	input [5:0]clkdivide;
	
	reg [5:0]cpucnt;
	reg cpuclk;
	always @(posedge clk) begin
		if (cpucnt == clkdivide) begin
		   cpuclk <= ~cpuclk;
		   cpucnt <= 6'd0;
		end
		else
			cpucnt <= cpucnt + 6'd1;
	end

endmodule

module clkdivide_r(reset,clkdivide_e_wr,clkdivide,data);
	input reset;
	input clkdivide_e_wr;
	output [5:0]clkdivide;
	input [5:0]data;
	
	reg [5:0]clkdivide;

	initial clkdivide <= 6'h05;
	
	always @(posedge clkdivide_e_wr,negedge reset) begin
		if (reset == 0) begin
			clkdivide <= 6'h05;
		end
		else begin
			clkdivide <= data[5:0];
		end
	end
	
endmodule

module dio(data,memmaprd,memmapdta,clkdivide_e_rd,clkdivide);
	output [7:0]data;
	input memmaprd;
	input [1:0]memmapdta;
	input clkdivide_e_rd;
	input [5:0]clkdivide;
	
	assign data = (clkdivide_e_rd) ? {{2'd0,clkdivide}} : (memmaprd) ? {{6'd0,memmapdta}} : 8'bZ;
	//assign data = 8'bZ;

endmodule

module memmap(reset,memmapwr,adr,data,memmapdta,outsel,out,memmaplock);
	input reset;
	input memmapwr;
	input [2:0]adr;
	input [1:0]data;
	output [1:0]memmapdta;
	input [2:0]outsel;
	output [1:0]out;
	input memmaplock;
	
	reg [1:0]memmap [7:0];
	
	assign memmapdta = memmap[adr];
	assign out = memmap[outsel];

	always @(negedge reset, posedge memmapwr) begin
		if (reset == 0) begin
			memmap[3'd0] <= 2'd0;
			memmap[3'd1] <= 2'd1;
			memmap[3'd2] <= 2'd1;
			memmap[3'd3] <= 2'd1;
			memmap[3'd4] <= 2'd1;
			memmap[3'd5] <= 2'd1;
			memmap[3'd6] <= 2'd1;
			memmap[3'd7] <= 2'd1;
		end
		else begin
			if ( memmaplock == 1 ) memmap[adr] <= data;
/*			case (adr) 
				0: memmap[0] <= data;
				1: memmap[1] <= data;
				2: memmap[2] <= data;
				3: memmap[3] <= data;
				4: memmap[4] <= data;
				5: memmap[5] <= data;
				6: memmap[6] <= data;
				7: memmap[7] <= data;
			endcase				
*/		end
	end
		
endmodule

