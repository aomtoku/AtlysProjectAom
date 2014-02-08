`timescale 1ns / 1ps

module gmii2fifo24#(
	parameter [31:0] ipv4_dst_rec     = {8'd192, 8'd168, 8'd0, 8'd1},
	parameter [15:0] dst_port_rec     = 16'd12345,
	parameter [15:0] dst_port_aux_rec = 16'd12346,
	parameter [15:0] ethernet_type    = 16'h0800, 
	parameter [7:0]	 ip_version       = 8'h45,
	parameter [7:0]	 ip_protcol       = 8'h11

)(
	input clk125,
	input sys_rst,
	input id,
	input wire [7:0]rxd,
	input wire rx_dv,
	output reg [28:0] datain,
	output reg [11:0] aux_in,
	output reg recv_en,
	output reg fifo_aux_rd,
	output wire video_en,
	output wire audio_en
);

`define YUV_MODE
reg video_dv;
reg [10:0] rx_count;
assign video_en = video_dv;

//---------------------------------------------------------
//  Ethernet Header & IP Header & UDP Header
//---------------------------------------------------------
reg [15:0]eth_type;
reg [7:0]ip_ver;
reg [7:0]ipv4_proto;
reg [31:0]ipv4_src;
reg [31:0]ipv4_dst;
reg [15:0]src_port;
reg [15:0]dst_port;

//----------------------------------------------------------
//
//  Counting the Recv Byte
//					& Check each Header
//----------------------------------------------------------
reg pre_en;
reg invalid;
reg [11:0]x_info;
reg [11:0]y_info;
reg audio_dv;

always@(posedge clk125) begin
	if(sys_rst) begin
		rx_count		<= 11'd0;
		eth_type		<= 16'h0;
		ip_ver			<= 8'h0;
		ipv4_proto	<= 8'h0;
		ipv4_src		<= 32'h0;
		ipv4_dst		<= 32'h0;
		src_port		<= 16'h0;
		dst_port		<= 16'h0;
		video_dv		<= 1'b0;
		x_info			<= 12'h0;
		y_info			<= 12'h0;
		pre_en			<= 1'b0;
		invalid 		<= 1'b0;
	end else begin
		if(rx_dv) begin
			rx_count <= rx_count + 11'd1;
			case(rx_count)
				11'h14: eth_type	[15:8]	<= rxd;
				11'h15: eth_type	[7:0]		<= rxd;
				11'h16: ip_ver		[7:0]		<= rxd;
				11'h1f: ipv4_proto[7:0]		<= rxd;
				11'h22: ipv4_src	[31:24]	<= rxd;
				11'h23: ipv4_src	[23:16]	<= rxd;
				11'h24: ipv4_src	[15:8]	<= rxd;
				11'h25: ipv4_src	[7:0]		<= rxd;
				11'h26: ipv4_dst	[31:24]	<= rxd;
				11'h27: ipv4_dst	[23:16]	<= rxd;
				11'h28: ipv4_dst	[15:8]	<= rxd;
				11'h29: ipv4_dst	[7:0]		<= rxd;
				11'h2a: src_port	[15:8]	<= rxd;
				11'h2b: src_port	[7:0]		<= rxd;
				11'h2c: dst_port	[15:8]	<= rxd;
				11'h2d: dst_port	[7:0]		<= rxd;
				11'h32: begin
					if(eth_type	[15:0] == ethernet_type &&
						ip_ver		[7:0]  == ip_version 		&&
						ipv4_proto[7:0]	 == ip_protcol 		&&
						ipv4_dst	[31:8] == ipv4_dst_rec[31:8] &&
						ipv4_dst	[7:0]  == (ipv4_dst_rec[7:0] + {7'd0, id}) &&
						dst_port	[15:0] == dst_port_rec) begin
							video_dv 	<= 1'b1;
							y_info[7:0]	<= rxd;
					end else if(eth_type[15:0] == ethernet_type &&
						ip_ver[7:0]    == ip_version &&
					  ipv4_proto[7:0]== ip_protcol &&
						ipv4_dst[31:8] == ipv4_dst_rec[31:8] &&
						ipv4_dst[7:0]  == (ipv4_dst_rec[7:0] + {7'd0, id}) &&
						dst_port[15:0] == dst_port_aux_rec) begin
							audio_dv 		<= 1'b1;
					end
				end
				11'h33: begin
					if(video_dv)begin
							y_info[11:8]	<= rxd[3:0];
							x_info[3:0]		<= rxd[7:4];
							pre_en				<= 1'b1;
					end
				end
				11'h73: begin
					if(audio_dv)
						audio_dv <= 	1'b0;
				end
				11'd1331: begin // before 11'd1005
					video_dv <= 1'b0;
					invalid <= 1'b1;
					pre_en <= 1'b0;
				end
			endcase
		end else begin
			rx_count	<= 11'd0;
			eth_type	<= 16'h0;
			ip_ver		<= 8'h0;
			ipv4_proto	<= 8'h0;
			ipv4_src	<= 32'h0;
			ipv4_dst	<= 32'h0;
			src_port	<= 16'h0;
			dst_port	<= 16'h0;
			video_dv 	<= 1'b0;
			pre_en		<= 1'b0;
			invalid		<= 1'b0;
		end
	end
end

//----------------------------------------------------------
//
//		Output Data for FIFO
//
//----------------------------------------------------------

parameter YUV_1 = 1'b0;
parameter YUV_2 = 1'b1;

reg [1:0] state_data;
reg [10:0] d_cnt;


always@(posedge clk125) begin
	if(sys_rst) begin
		state_data 	<= YUV_1;
		datain 			<= 29'd0;
		recv_en 		<= 1'd0;
		d_cnt				<= 11'd0;
	end else begin
		if(video_dv && pre_en) begin
			if(state_data == YUV_1) begin
				datain[28:27] 	<= {1'b0,x_info[0]};
				datain[26:16] 	<= y_info[10:0];
				datain[15:8] 		<= rxd;
				state_data 			<= YUV_2;
				recv_en 				<= 1'b0;
			end else begin
				recv_en 				<= 1'b1;
				state_data 			<= YUV_1;
				datain[7:0] 		<= rxd;
				d_cnt						<= d_cnt + 11'd1;
			end			
		end else begin
			state_data 	<= YUV_1;
			if(invalid) begin
				datain 					<= 29'd0;
				recv_en 				<= 1'b0;
				d_cnt						<= 11'd0;
			end else begin
				recv_en 				<= 1'b0;
				d_cnt						<= 11'd0;
			end
		end
	end
end


//--------------------------------------------------------
//
//   AUDIO/AUX receive to FIFO
//
//--------------------------------------------------------
reg [3:0]tmp;
reg pck_num;
reg [5:0]pck_cnt;
reg fifo_aux_wr;

always @ (posedge clk125) begin
	if(sys_rst) begin
		aux_in 			<= 12'd0;
		tmp					<= 4'd0;
		pck_num			<= 2'd0;
		fifo_aux_rd <= 1'b0;
		fifo_aux_wr <= 1'b0;
	end else begin
		if(audio_dv)begin
			pck_cnt <= pck_cnt + 6'd1;
			case(pck_num)
				2'd0 : 	begin 
											pck_num 			<= 2'd1;
											aux_in[7:0] 	<= rxd; 
											fifo_aux_rd 	<= 1'b0; 
											fifo_aux_wr   <= 1'b0;
								end
				2'd1 : 	begin 	
											pck_num 			<= 2'd2;
											aux_in[11:8] 	<= rxd[3:0]; 
											tmp 					<= rxd[7:4]; 
											fifo_aux_rd 	<= 1'b1; 
											fifo_aux_wr   <= 1'b1;
								end
				2'd2 : 	begin
											pck_num				<= 2'd0;
											aux_in 				<= {aux_in, tmp};
											fifo_aux_rd 	<= 1'b1;
											fifo_aux_wr   <= 1'b1;
								end
			endcase
		end else begin
			pck_cnt <= 6'd0;
		end
	end
end
endmodule