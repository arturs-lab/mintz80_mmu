// 256 no clk, ramen2
module mintz80_mmu(clk,reset,rd,wr,a07,a1513,data,mreq,iorq,ramen,romen,b14,b16,ramen2,beep);
	input clk;
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
	output ramen2;
	output beep;

	wire romen;
	wire ramen;
	wire memmapwr;
	wire [2:0]memmap;
	wire ioe;
	
	reg memmaplock;
	assign romen = (mreq || memmap[0]);	// memmap[0] low
	assign ramen = (mreq || ~memmap[0] || memmap[2]);	// memmap[0] high, memmap[2] low
	assign ramen2 = (mreq || ~memmap[0] || ~memmap[2]);	// memmap[0] high, memmap[2] high
	assign b16=memmap[1];
	assign b14=(memmap[0]==0) ? memmap[1] : a1513[14];

	// ioe equ $d0 - $df
	assign ioe = !iorq && a07[7] && a07[6] && ~a07[5] && a07[4];

	// memmap	equ $d8-df
	assign memmapwr = (!wr && ioe && a07[3]);
	assign memmaprd = (!rd && ioe && a07[3]);

	// select clock or beeper $d0-d1
	assign clk_or_beep = (ioe && ~a07[3] && ~a07[2] && ~a07[1] );
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

	
	dio dio(
		.data (data),
		.memmaprd (memmaprd),
		.memmap (memmap[2:0]),
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
		.memmaplock (memmaplock)
	);
		
endmodule


module dio(data,memmaprd,memmap);
	output [7:0]data;
	input memmaprd;
	input [2:0]memmap;
	
	assign data = (memmaprd) ? {{5'd0,memmap}} : 8'bZ;
	//assign data = 8'bZ;

endmodule

module memmapr(reset,memmapwr,adr,data,out,outsel,out,memmaprd,memmaplock);
	input reset;
	input memmapwr;
	input [2:0]adr;
	input [2:0]data;
	output [2:0]out;
	input [2:0]outsel;
	input memmaprd;
	input memmaplock;
	
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


