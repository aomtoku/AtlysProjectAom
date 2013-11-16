`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    18:06:07 08/27/2013 
// Design Name: 
// Module Name:    gmii_tx 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
`define DATA_YUV

module gmii_tx#(
	parameter [47:0]src_mac		= {8'h00,8'h23,8'h45,8'h67,8'h89,8'hab},
	parameter [47:0]dst_mac		= {8'h00,8'h93,8'h45,8'h67,8'h89,8'hab},
	parameter [15:0] ip_type		= 16'h0800,
	parameter [15:0] ip_ver		= 16'h4500,
`ifdef DATA_YUV
	parameter [15:0] ip_len		= 16'd1312 - 16'd2,
`else
	parameter [15:0] ip_len		= 16'd992,
`endif
	parameter [15:0] ip_iden		= 16'h0000,
	parameter [15:0] ip_flag		= 16'h4000,
	parameter [7:0] ip_ttl			= 8'h40,
	parameter [7:0] ip_prot		= 8'h11,
	parameter [31:0]ip_src_addr 	= {8'd192,8'd168,8'd0,8'd2},
	parameter [31:0]ip_dst_addr 	= {8'd192,8'd168,8'd0,8'd1},
`ifdef DATA_YUV
	parameter [15:0] udp_len		= 16'd1292 - 16'd2 //  (Pixel = 1280) + (X,Y = 4) + (UDP header= 8)
`else
	parameter [15:0] udp_len		= 16'd972 // (Pixel = 960) + (X,Y = 4) + (UDP header = 8)
`endif
)(
	/*** FIFO ***/
	input	wire 	fifo_clk,
	input 		 sys_rst,
	input wire[47:0] dout,
	input	wire	 empty,
	input wire	 full,
	output wire	 rd_en,
	input wire	 wr_en,
	
	/*** Ethernet PHY GMII ***/
	input wire	 tx_clk,
	output reg	 tx_en,
	//output wire [3:0]debug,
	output reg [7:0] txd
);


//
// MODE  DATA_YUV 
//    1280x720 YUV422
//   	 G(channel 1) --> Y  8bit
//	 R(channel 2) --> Cb 8bit/ Cr8bit
//
//	 Packet is
//	 UDP Header |Y(2 Byte) | X(2 Byte) | Y0(1Byte) | Cb0(1Byte) | Y1(1Byte)
//	 | Cr1(1Byte) .............
//
`define DATA_YUV

assign debug = state;
//
//  LOGIC
//
parameter IDLE		 	= 4'h0;
parameter PRE 			= 4'h1;
parameter SFD 			= 4'h2;
parameter DATA_ETH	= 4'h3;
parameter DATA_IP		= 4'h4;
parameter DATA_RESOL	= 4'h5;
parameter DATA_RGB	= 4'h6;
parameter FCS 			= 4'h7;
parameter IFG			= 4'h8;


reg [3:0] state;
reg [10:0] count;
reg [1:0] fcs_count;
reg [1:0] cnt3;
reg [31:0] gap_count;

//
// Parameter of IP/UDP header
//
/*wire [47:0]src_mac		= {8'h00,8'h23,8'h45,8'h67,8'h89,8'hab}; 
wire [47:0]dst_mac		= {8'h00,8'h93,8'h45,8'h67,8'h89,8'hab};
wire [15:0] ip_type		= 16'h0800;
wire [15:0] ip_ver		= 16'h4500;
`ifdef DATA_YUV
wire [15:0] ip_len		= 16'd1312;
`else
wire [15:0] ip_len		= 16'd992;
`endif
wire [15:0] ip_iden		= 16'h0000;
wire [15:0] ip_flag		= 16'h4000;
wire [7:0] ip_ttl			= 8'h40;
wire [7:0] ip_prot		= 8'h11;
reg  [23:0] ip_check;
wire [31:0]ip_src_addr 	= {8'd192,8'd168,8'd0,8'd2};
wire [31:0]ip_dst_addr 	= {8'd192,8'd168,8'd0,8'd1};
`ifdef DATA_YUV
wire [15:0] udp_len		= 16'd1292; //  (Pixel = 1280) + (X,Y = 4) + (UDP header= 8)
`else
wire [15:0] udp_len		= 16'd972; // (Pixel = 960) + (X,Y = 4) + (UDP header = 8)
`endif
*/
//
// CRC 
//

reg	crc_rd;
reg	crc_init;// = (state == SFD && count ==0);
wire [31:0]crc_out;
wire	crc_data_en = ~crc_rd;

//`define simulation
//`ifndef simulation
crc_gen crc_gen(
	.Reset(sys_rst),
	.Clk(tx_clk),
	.Init(crc_init),
	.Frame_data(txd),
	.Data_en(crc_data_en),
	.CRC_rd(crc_rd),
	.CRC_out(crc_out),
	.CRC_end()
);

//`endif

//-------------------------------------------
//  FIFO control 
//     
//-------------------------------------------

reg fstate,ppl;  
reg buf1_wr_en, buf2_wr_en; //To aboid Metastability
reg buf1_tx_en, buf2_tx_en;
wire send_enable = fstate;

always @(posedge fifo_clk)begin
	if(sys_rst)begin
		fstate <= 1'b0;
		ppl <= 1'b0;
		buf1_wr_en <= 1'b0;
		buf2_wr_en <= 1'b0;
	end
		else begin
			buf1_wr_en <= wr_en;
			buf2_wr_en <= buf1_wr_en;
			buf1_tx_en <= tx_en;
			buf2_tx_en <= buf1_tx_en;
			if({buf1_wr_en,buf2_wr_en}==2'b01)
				fstate <= 1'b1;
			if({buf1_tx_en,buf2_tx_en}==2'b01) begin
				if(ppl)begin
					ppl <= 1'b0;
					fstate <= 1'b0;
				end else begin
					ppl <= 1'b1;
				end
			end
	end

end

//
// Logic
//
reg [23:0] ip_check;

always @(posedge tx_clk )begin
	if(sys_rst)begin
		txd	<= 8'd0;
		tx_en	<= 1'd0;
		count	<= 11'd0;
		state	<= IDLE;
		cnt3 <= 2'd0;
		fcs_count <= 2'd0;
		crc_rd <= 1'b1;
		gap_count <= 32'd0;
		crc_init <= 1'd0;
		ip_check <= 24'd0;
	end else begin
		crc_rd <= 1'b0; 
		case(state)
			IDLE:	begin
					if(empty == 1'b0 & send_enable)begin
							txd	<= 8'h55;
							tx_en	<= 1'b1;
							state <= PRE;
							ip_check <= {8'd0,ip_ver} + {8'd0,ip_len} + {8'd0,ip_iden} + {8'd0,ip_flag} + {8'd0,ip_ttl,ip_prot} + {8'd0,ip_src_addr[31:16]} + {8'd0,ip_src_addr[15:0]} + {8'd0,ip_dst_addr[31:16]} + {8'd0,ip_dst_addr[15:0]};
					end
				end
			PRE:	begin
						tx_en	<= 1'b1;
						count <= count + 11'h1;
						case(count)
							11'h0:	txd	<= 8'h55;
							11'h5:	begin
									txd	<= 8'h55;
									ip_check <= ~(ip_check[15:0] + ip_check[23:16]);
									state <= SFD;
									count <= 11'h0;
								end
							//default tx_en <= 1'b0;
						endcase
						end
			SFD:	begin
						txd	<= 8'hd5;
						crc_init <= 1'd1;
						state	<= DATA_ETH;
					end
	 DATA_ETH:	begin
						tx_en	<= 1'b1;
						count <= count + 11'h1;
						crc_init <= 1'd0;
						case(count)
							/* DST MAC 00:23:45:67:89:ac */
							10'h0: txd	<= dst_mac[47:40];
							10'h1: txd	<= dst_mac[39:32];
							10'h2: txd	<= dst_mac[31:24];
							10'h3: txd	<= dst_mac[23:16];
							10'h4: txd	<= dst_mac[15:8];
							10'h5: txd	<= dst_mac[7:0];
							/* SRC MAC 00:23:45:67:89:ab */
							10'h6: txd	<= src_mac[47:40];
							10'h7: txd	<= src_mac[39:32];
							10'h8: txd	<= src_mac[31:24];
							10'h9: txd	<= src_mac[23:16];
							10'ha: txd	<= src_mac[15:8];
							10'hb: txd	<= src_mac[7:0];
							/* IP TYPE  0800 = */
							10'hc: txd	<= ip_type[15:8];
							10'hd: 	begin
									state <= DATA_IP;
									txd	<= ip_type[7:0];
									count <= 11'h0;
						 		end
							//default: tx_en <= 1'b0;
						endcase
					end
		DATA_IP:	begin
						tx_en	<= 1'b1;
						count <= count + 11'h1;
						case(count)
							/* IP Verision = 4 & IP header Length = 20byte ----> 8'h45 */
							10'h0: txd	<= ip_ver[15:8];
							/* DSF */
							10'h1: txd	<= ip_ver[7:0];
							/* Total Length  992byte (=0x03e0) */
							10'h2: txd	<= ip_len[15:8];
							10'h3: txd	<= ip_len[7:0];
							/* Identification  ---> <<later>> */
							10'h4: txd	<= ip_iden[15:8];
							10'h5: txd	<= ip_iden[7:0];
							/* Flag */
							10'h6: txd	<= ip_flag[15:8];
							10'h7: txd	<= ip_flag[7:0];
							/* TTL  64 = 0x40 */
							10'h8: txd	<= ip_ttl;
							/* Protocol = (UDP =  17 ==0x11 )*/
							10'h9: txd	<= ip_prot;
							/* checksum = *(culcurate) */
							10'ha: txd	<= ip_check[15:8];
							10'hb: txd	<= ip_check[7:0];
							/* IP v4 SRC Address 10.0.21.9 */
							10'hc: txd	<= ip_src_addr[31:24];
							10'hd: txd	<= ip_src_addr[23:16];
							10'he: txd	<= ip_src_addr[15:8];
							10'hf: txd	<= ip_src_addr[7:0];
							/* IP v4 DEST Adress 203.178.143.241 */
							10'h10: txd	<= ip_dst_addr[31:24];
							10'h11: txd	<= ip_dst_addr[23:16];
							10'h12: txd	<= ip_dst_addr[15:8];
							10'h13: txd	<= ip_dst_addr[7:0];
							/* UDP SRC PORT 12344  = 0x3038 */
							10'h14: txd	<= 8'h30;
							10'h15: txd	<= 8'h38;
							/* UDP DEST PORT 12345 = 0x3039 */
							10'h16: txd	<= 8'h30;
							10'h17: txd	<= 8'h39;
							/* UDP Length 972byte = 0x03cc */
							10'h18: txd	<= udp_len[15:8];
							10'h19: txd	<= udp_len[7:0];
							/* UDP checksum ͐ݒ肵ȂĂH*/
							10'h1a: begin
										txd	<= 8'h00;
										cnt3 <= 2'd3;
									  end
							10'h1b: begin
									txd	<= 8'h00;
									count 	<= 11'd0;
									state	<= DATA_RESOL;
									cnt3	<= 2'd0; //read X,Y in FIFO.
								end
							//default: tx_en <= 1'b0;
						endcase
					end
						//
						//   test mode
						//			1280x720
						//			1280 x 3 = 3840 byte/line
						//       3840 / 4 = 960 byte/packet
						//      ---> 1line4đB
						//
	DATA_RESOL: begin
						cnt3	<= 2'd2;
						tx_en <= 1'b1;
						count <= count + 11'h1;
						case(count)
							10'h0: txd	<= dout[43:36];
							10'h1: begin
									   txd	<= {dout[27:24],dout[47:44]};
										count <= 11'h0;
										cnt3 <= 2'd3;
										state <= DATA_RGB;
									 end

						/* Y resoluction */ 
							/*
							10'h0: txd	<= dout[43:36];
							10'h1: txd	<= {4'b0,dout[47:44]};
							*/
						/* X resoluction */
							/*
							10'h2: txd	<= dout[31:24];
							10'h3: 	begin
									txd	<= {4'b0,dout[35:32]};
									count <= 11'h0;
									cnt3 <= 2'd3;
									state <= DATA_RGB;
								end
							*/
							//default: tx_en 	<= 1'b0; 
						endcase
					    end
				`ifdef DATA_YUV
		DATA_RGB:	begin
							if(count == 11'd1279)begin
							    state <= FCS;
								 txd <= dout[23:16];
							    count <= 11'd0;
								 cnt3 <= 2'd0;
							end else begin
								tx_en <= 1'b1;
								count <= count + 11'h1;
								casex(cnt3)
									2'b1x: begin
											txd <= /*dout[31:24]*/dout[15:8]; // Green
											cnt3 <= 2'd1;
										end
									2'b01: begin
											txd <= /*{4'd0,dout[35:32]}*/dout[23:16];  // Red
											cnt3 <= 2'd2;
								       		end
									//default: tx_en <= 1'b0;
								endcase
							end
						end
				`else
		DATA_RGB:	begin
							tx_en <= 1'b1;
							count <= count + 11'h1;	
							casex(cnt3)
								2'b1x: 	begin
										txd <= dout[7:0]; // Red
										cnt3 <= 2'd1;
									end
								2'b01: 	begin
										txd <= dout[15:8];  // Green
										cnt3 <= 2'd0;
									end 
								2'b00: 	begin
										txd <= dout[23:16];
										cnt3 <= 2'd2;// Blue
									end
								//default: tx_en <= 1'b0;
							endcase
							if(count == 11'd959 )begin
									state <= FCS;
									count <= 11'd0;
							end 
						end
				`endif
				FCS:	begin
							tx_en <= 1'b1;
							fcs_count <= fcs_count + 1'b1;
							crc_rd <= 1'b1;
							case(fcs_count)
								2'h0: txd <= crc_out[31:24];
								2'h1: txd <= crc_out[23:16];
								2'h2: txd <= crc_out[15:8];
								2'h3: begin
										txd <= crc_out[7:0];
										gap_count <= 32'd14; // Inter Frame Gap = 14 (offset value -2)
										state <= IFG;
								      end
								//default : tx_en <= 1'b0;
							endcase
						end
						//
						// Inter Frame Gap needs 96bitTime at least
						//       96 / 10^9 = 0.096microsec
						//       12 clock in 125MHz
						//
				IFG:	begin
							if(gap_count == 32'd0) 
									state <= IDLE;
							else begin
									tx_en <= 1'b0;
									gap_count <= gap_count - 32'd1;
							end
						end
			//default: tx_en <= 1'b0;
		endcase
	end
end

reg zero = 0;
assign rd_en = ((state == DATA_RGB & cnt3 == 2'd2 ) | (state == DATA_RESOL & cnt3 == 2'd3 ) | (state == DATA_IP & cnt3 == 2'd3 )); //? cnt3[1]: zero;

endmodule
