`timescale 1ns / 1ps

module gmii2fifo24#(
	parameter [31:0] ipv4_dst_rec  = {8'd192, 8'd168, 8'd0, 8'd1},
	parameter [15:0] dst_port_rec  = 16'd12345,
	parameter [15:0] ethernet_type = 16'h0800, 
	parameter [7:0]  ip_version    = 8'h45,
	parameter [7:0]  ip_protcol    = 8'h11

)(
	input  wire        clk125,
	input  wire        sys_rst,
	input  wire        id,
	input  wire [7:0]  rxd,
	input  wire        rx_dv,
	output reg  [28:0] datain,
	output reg         recv_en,
	output wire        packet_en,
	// AUX FIFO
	output wire [34:0] aux_data_in,
	output wire        aux_wr_en
);

`define YUV_MODE
reg        packet_dv;
reg [10:0] rx_count;

assign packet_en = packet_dv;

//---------------------------------------------------------
//  Ethernet Header & IP Header & UDP Header
//---------------------------------------------------------
reg [15:0] eth_type;
reg [ 7:0] ip_ver;
reg [ 7:0] ipv4_proto;
reg [31:0] ipv4_src;
reg [31:0] ipv4_dst;
reg [15:0] src_port;
reg [15:0] dst_port;
reg [15:0] udp_len;


//----------------------------------------------------------
//
//  Counting the Recv Byte
//					& Check each Header
//----------------------------------------------------------
reg        pre_en;
reg        vinvalid;
reg        audio_en;
reg [11:0] x_info;
reg [11:0] y_info;
reg [ 3:0] pcktinfo;
reg [ 3:0] adenum; 

parameter video = 4'b0000;
parameter audio = 4'b0001;
parameter vidax = 4'b0010;

always@(posedge clk125) begin
	if(sys_rst) begin
		rx_count    <= 11'd0;
		eth_type    <= 16'h0;
		ip_ver      <= 8'h0;
		ipv4_proto  <= 8'h0;
		ipv4_src    <= 32'h0;
		ipv4_dst    <= 32'h0;
		src_port    <= 16'h0;
		dst_port    <= 16'h0;
		udp_len     <= 16'h0;
		packet_dv   <= 1'b0;
		x_info      <= 12'h0;
		y_info      <= 12'h0;
		pre_en      <= 1'b0;
		audio_en    <= 1'b0;
		vinvalid    <= 1'b0;
		pcktinfo    <= 4'd0;
		adenum      <= 4'd0;
	end else begin
		if(rx_dv) begin
			rx_count <= rx_count + 11'd1;
			case(rx_count)
				11'h14: eth_type  [15:8]  <= rxd;
				11'h15: eth_type  [7:0]   <= rxd;
				11'h16: ip_ver    [7:0]   <= rxd;
				11'h1f: ipv4_proto[7:0]   <= rxd;
				11'h22: ipv4_src  [31:24] <= rxd;
				11'h23: ipv4_src  [23:16] <= rxd;
				11'h24: ipv4_src  [15:8]  <= rxd;
				11'h25: ipv4_src  [7:0]   <= rxd;
				11'h26: ipv4_dst  [31:24] <= rxd;
				11'h27: ipv4_dst  [23:16] <= rxd;
				11'h28: ipv4_dst  [15:8]  <= rxd;
				11'h29: ipv4_dst  [ 7:0]  <= rxd;
				11'h2a: src_port  [15:8]  <= rxd;
				11'h2b: src_port  [ 7:0]  <= rxd;
				11'h2c: dst_port  [15:8]  <= rxd;
				11'h2d: dst_port  [ 7:0]  <= rxd;
				11'h2e: udp_len   [ 7:0]  <= rxd;
				11'h2f: udp_len   [15:8]  <= rxd;
				11'h32: begin
					if(eth_type [15:0] == ethernet_type &&
						ip_ver    [ 7:0] == ip_version &&
						ipv4_proto[ 7:0] == ip_protcol &&
						ipv4_dst  [31:8] == ipv4_dst_rec[31:8] &&
						ipv4_dst  [ 7:0] == (ipv4_dst_rec[7:0] + {7'd0, id}) &&
						dst_port  [15:0] == dst_port_rec) begin
						// packet info byte
						case(rxd[3:0])
						  video: packet_dv   <= 1'b1;
						  vidax: packet_dv   <= 1'b1;
						  audio: audio_en    <= 1'b1;
					  endcase
						pcktinfo <= rxd[3:0];
						adenum   <= rxd[7:4];
						//finish  <= rx_count + udp_len;
					end
				end
				11'h33: if(packet_dv) begin
						y_info[7:0]	<= rxd;
				end
				11'h34: if(packet_dv) begin //11'd52
					 y_info[11:8]	<= rxd[3:0];
					 x_info[ 3:0] <= rxd[7:4];
					 pre_en       <= 1'b1;
				end
				11'd1252: begin // before 11'd1005 --> 1200byte
				    case(pcktinfo)
						video:   audio_en  <= 1'b0;
						vidax:   audio_en  <= 1'b1;
						default: audio_en <= 1'b0;
					endcase
					packet_dv <= 1'b0;
					vinvalid  <= 1'b1;
					pre_en    <= 1'b0;
				end
			endcase
			if(left == adenum && a_cnt == 6'd35)
				audio_en <= 1'b0;
		end else begin
			rx_count    <= 11'd0;
			eth_type    <= 16'h0;
			ip_ver      <= 8'h0;
			ipv4_proto  <= 8'h0;
			ipv4_src    <= 32'h0;
			ipv4_dst    <= 32'h0;
			src_port    <= 16'h0;
			dst_port    <= 16'h0;
			packet_dv   <= 1'b0;
			pre_en      <= 1'b0;
			vinvalid    <= 1'b0;
			audio_en    <= 1'b0;
			pcktinfo    <= 4'd0;
			adenum      <= 4'd0;
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

reg [ 1:0]  state_data;
reg [10:0] d_cnt;

always@(posedge clk125) begin
	if(sys_rst) begin
		state_data  <= YUV_1;
		datain      <= 29'd0;
		recv_en     <= 1'd0;
		d_cnt       <= 11'd0;
	end else begin
		if(packet_dv && pre_en) begin
			if(state_data == YUV_1) begin
				datain[28:27]  <= {1'b0,x_info[0]};
				datain[26:16]  <= y_info[10:0];
				datain[15:8]   <= rxd;
				state_data     <= YUV_2;
				recv_en        <= 1'b0;
			end else begin
				recv_en      <= 1'b1;
				state_data   <= YUV_1;
				datain[7:0]  <= rxd;
				d_cnt        <= d_cnt + 11'd1;
			end			
		end else begin
			state_data  <= YUV_1;
			if(vinvalid) begin
				datain    <= 29'd0;
				recv_en   <= 1'b0;
				d_cnt     <= 11'd0;
			end else begin
				recv_en   <= 1'b0;
				d_cnt     <= 11'd0;
			end
		end
	end
end

//--------------------------------------------------------
// AUX data processing
//--------------------------------------------------------

reg [ 1:0]cnt2;
reg [ 5:0]a_cnt;
reg [ 3:0]left;
reg [8:0]daux;
reg [15:0]pos;
reg [7:0] tmp;
reg [3:0] c9;
reg       ax_wr_en;
reg       aux_state;
reg [9:0] auxy;
assign aux_wr_en   = ax_wr_en;
assign aux_data_in = {auxy,pos,daux};

parameter AUXID = 2'b00;
parameter AUX   = 2'b01;
parameter NO    = 2'b10;

always@(posedge clk125)begin
  if(sys_rst) begin
		tmp       <=  8'd0;
		c9        <=  4'd0;
		left      <=  4'd0;
		cnt2      <=  2'd0;
		ax_wr_en  <=  1'b0;
		aux_state <=  1'b0;
		a_cnt     <=  6'd0;
		daux      <=  9'd0;
		pos       <= 16'd0;
		auxy      <= 10'd0;
	end else begin
	  if(audio_en) begin
      case(aux_state)
		    AUXID:begin
			    if(a_cnt == 6'd1)begin
					  a_cnt      <= 6'd0;
					  aux_state  <= AUX;
					  ax_wr_en   <= 1'b0;
					  pos[15:8]  <= rxd;
					  auxy       <= y_info[9:0];
					  left       <= left + 1;
			    end else begin
					  ax_wr_en  <= 1'b0;
				    a_cnt     <= 6'd1;
					  pos[7:0] <= rxd;
			    end
			end
			AUX:begin
			    if(c9 == 4'd8)
					c9 <= 4'd0;
				else
			        c9 <= c9 + 4'd1;
			    if(a_cnt == 6'd35)begin
				    a_cnt      <= 6'd0;
				    cnt2       <= 2'd0;
					daux[ 8:0] <= {rxd,tmp[0]};
				    ax_wr_en   <= 1'b0;
					if(left == adenum)begin
						aux_state <=  NO;
					end else
			  	        aux_state  <= AUXID;
				 end else begin
				    a_cnt <= a_cnt + 6'd1; // counting 32 clock cycles for audio data enable
						//daux[12] <= 1'b0;
						//daux[11:9] <= left[2:0];
						//ax_wr_en   <= 1'b1;
						//daux[ 7:0] <= rxd;
					  case(c9)
					    4'd0 : begin
						           if(pos == 0)
									   pos <= 30;
						           daux[7:0] <= rxd;
								  		 ax_wr_en  <= 1'b0;
								  	 end
					    4'd1 : begin
						           daux[8]  <= rxd[0];
								  		 tmp[6:0] <= rxd[7:1];
									  	 ax_wr_en <= 1'b1;
									   end
					    4'd2 : begin
						           daux[8:0]     <= {rxd[1:0],tmp[6:0]};
								  		 tmp[5:0] <= rxd[7:2];
										   ax_wr_en <= 1'b1;
									   end
					    4'd3 : begin
						           daux[8:0] <= {rxd[2:0],tmp[5:0]};
							  			 tmp[4:0]  <= rxd[7:3];
								  		 ax_wr_en  <= 1'b1;
									   end
			   		  4'd4 : begin
				  		         daux[8:0] <= {rxd[3:0],tmp[4:0]};
					  					 tmp[3:0]  <= rxd[7:4];
						  				 ax_wr_en  <= 1'b1;
							  		 end
					    4'd5 : begin
						           daux[8:0] <= {rxd[4:0],tmp[3:0]};
								  		 tmp[2:0]  <= rxd[7:5];
									  	 ax_wr_en  <= 1'b1;
									   end
				   	  4'd6 : begin
					  	         daux[8:0] <= {rxd[5:0],tmp[2:0]};
						  				 tmp[1:0]  <= rxd[7:6];
							  			 ax_wr_en  <= 1'b1;
								  	 end
					    4'd7 : begin
						           daux[8:0] <= {rxd[6:0],tmp[1:0]};
							  			 tmp[0]  <= rxd[7];
								  		 ax_wr_en  <= 1'b1;
									   end
					    4'd8 : begin
						           daux[8:0] <= {rxd,tmp[0]};
							  			 ax_wr_en  <= 1'b1;
								  	 end
					  endcase
					end
				end
				NO: ax_wr_en <= 1'b0;
			  default : ax_wr_en <= 1'b0;
		  endcase
	  end else begin
	    left <= 4'd0;
	    ax_wr_en  <= 1'b0;
			aux_state <= 1'b0;
	  end
  end
end

endmodule
