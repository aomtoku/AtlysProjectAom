`timescale 1ns / 1ps

`define simulation

module tb_ether();


//
// System Clock 125MHz
//
reg sys_clk;
initial sys_clk = 1'b0;
always #4 sys_clk = ~sys_clk;

reg gmii_tx_clk;
initial gmii_tx_clk = 1'b0;
always #4 gmii_tx_clk = ~gmii_tx_clk;

reg fifo_clk;
initial fifo_clk = 1'b0;
always #6.734 fifo_clk = ~fifo_clk;

// Generate Video Signal
// for Gmii_tx
wire vsync, hsync;
reg [10:0]hcnt,vcnt;
assign vsync = (vcnt >= 746 || vcnt == 0);
assign hsync = (hcnt >= 1611 || hcnt == 0);
always@(posedge fifo_clk)begin
  if(sys_rst)begin
	  hcnt <= 11'd0;
	  vcnt <= 11'd0;
  end else begin
    if(hcnt == 1649)begin
	  hcnt <= 11'd0;
	  if(vcnt == 749)
	    vcnt <= 11'd0;
	  else
		vcnt <= vcnt + 11'd1;
	end else begin
      hcnt <= hcnt + 11'd1;
	end
  end
end

wire vde = (hcnt > 220 && hcnt < 1500) && (vcnt > 20 && vcnt < 740); 

wire fifo_read = vde;

//
// generate Audio Enable period
//

reg [4:0] adecnt;
reg [11:0]aclkc;
reg ade;
reg vde_h,ade_q;
reg init, initq,initqq;
wire [24:0]axdout;

//assign ax_recv_rd_en = ({init,initq} == 2'b10) || ade || ade_q;

always@(posedge fifo_clk)begin
    if(sys_rst)begin
		ade      <=  1'b0;
		adecnt   <=  6'd0;
		vde_h    <=  1'b0;
		aclkc    <= 12'd0;
		ade_q    <=  1'b0;
		init     <=  1'b0;
		initq    <=  1'b0;
		initqq   <=  1'b0;
	end else begin
	    vde_h  <= vde;
	    ade_q  <= ade;
	    initq  <= init;
		initqq <= initq; 
        //first read signal
        if(fifo_read) begin
		    init <= 1'b1;
	    end
		if({initq,initqq}==2'b10 || {ade,ade_q}==2'b01) begin
			aclkc <= axdout[23:12]; 
		end
		
	    if(init & ~vde /*& ~ade*/ & hcnt == aclkc) begin
		    ade <= 1'b1;
	    end
		// Aux Data Enable period 
	    if(ade)begin
		    if(adecnt == 6'd31)begin
			    ade    <= 1'b0;
		        adecnt <= 6'd0;
		    end else begin
			    adecnt <= adecnt + 6'd1;
		    end
	    end
    end
end



// Generate AUDIO FIFO data
wire [23:0]axdin_s,axdout_s;
wire ax_s_empty, ax_s_full;
wire ax_s_wr_en, ax_s_rd_en;
reg [11:0]ade_buf, ade_hcnt;
reg [23:0]ade_out;
reg ade_gg;
reg start;
reg st,stc;


reg       vblnk;
reg [ 5:0]acnt;
reg [ 2:0]astate;
reg [10:0]clk_ade;

parameter FIRST = 3'd0;
parameter READY = 3'd1;
parameter IDLE  = 3'd2;
parameter ADE   = 3'd3;
parameter ADE_L = 3'd4;

wire [15:0] ctim = axdout[24:9];

reg [15:0] txpos;
always @ (posedge pclk)begin
  if(RSTBTN | reset)
	  txpos <= 16'd0;
  else begin
	  if(vde)
		  txpos <= 16'd0;
      else
		  txpos <= txpos + 16'd1;
  end
end

always@(posedge pclk)begin
	if(RSTBTN | reset)begin
		ax_recv_rd_en <= 1'b0;
		astate        <= 3'd0; 
		clk_ade       <= 11'd0;
	  acnt          <= 6'd0;
		vblnk         <= 1'b0;
	end else begin
	  case(astate)
          READY : begin
                    if(vde) begin
                       ax_recv_rd_en <= 1'b1;
                       astate <= IDLE;
                    end
                  end
          IDLE  : begin
			         if(txpos == ctim)begin
                        ax_recv_rd_en <= 1'b0;
                        astate <= ADE;
                        acnt <= 6'd0;
                     end else
                        ax_recv_rd_en <= 1'b0;
                  end
          ADE   : begin
                     acnt <= acnt + 6'd1;
                     ax_recv_rd_en <= 1'b1;
                     if(acnt == 6'd30)
                        astate <= ADE_L;
                  end
          ADE_L : begin
                     if(txpos == ctim)begin
                        astate  <= ADE;
                        acnt    <= 6'd0;
                     end else begin
                        astate  <= IDLE;
                        clk_ade <= ctim;
                        ax_recv_rd_en <= 1'b1;
                     end
                  end
		endcase
		
	end
end


// Generating a Number of audio enable period
reg [3:0] ade_c;
reg [3:0] ade_numd;
reg [4:0] cnt_32;
reg       vde_b;
always @ (posedge fifo_clk)begin
  vde_b <= vde;
  if(sys_rst || {vde,vde_b}==2'b10)begin
	  ade_c  <= 4'd0;
	  cnt_32 <= 5'd0; 
	  ade_numd <= ade_c;
   end else begin
	  if(ade)begin
		  if(cnt_32 == 5'd31)begin
			cnt_32 <= 5'd0;
			ade_c  <= ade_c + 4'd1;
		  end else begin
		    cnt_32 <= cnt_32 + 5'd1;
		  end
		end
	end
end

//
// Test Bench
//
reg sys_rst;
reg empty = 0;
reg full  = 0;
wire rd_en;
wire TXEN;
wire [7:0]TXD;
reg [47:0]tx_data;


wire ade_tx = ((vcnt < 11'd22) || (vcnt > 11'd741)) && ((hcnt >= 11'd1) && (hcnt < 11'd80));
wire [3:0]ade_num = (vcnt >= 22 && vnct <= 741) ? 4'd0 : 4'd10;

gmii_tx gmiisend(
    .id(1'b1),
	/*** FIFO ***/
	.fifo_clk(fifo_clk),
	.sys_rst(sys_rst),
	.dout(tx_data), //48bit
	.empty(empty),
	.full(full),
	.rd_en(rd_en),
	.wr_en(vde),
	// AX FIFO
	.adesig(ade_tx),
	.ade_num(ade_num),
	.axdout(axdout_s),
	.ax_send_full(ax_s_full),
	.ax_send_empty(ax_s_empty),
	.ax_send_rd_en(ax_s_rd_en),

	/*** Ethernet PHY GMII ****/
	.tx_clk(gmii_tx_clk),
	.tx_en(TXEN),
	.txd(TXD)
);

afifo24 afifo24_send (
    .Data(axdin_s),
    .WrClock(fifo_clk),
    .RdClock(sys_clk),
    .WrEn(ax_s_wr_en),
    .RdEn(ax_s_rd_en),
    .Reset(sys_rst),
    .RPReset(sys_rst),
    .Q(axdout_s),
    .Empty(ax_s_empty),
    .Full(ax_s_full)
);

wire [28:0]fifo_din;
wire recv_fifo_wr_en;
wire [24:0]axdin;
wire ax_recv_wr_en;

gmii2fifo24 gmii2fifo24(
	.clk125(sys_clk),
	.sys_rst(sys_rst),
	.id(1'b0),
	.rxd(TXD),
	.rx_dv(TXEN),
	.datain(fifo_din),
	.recv_en(recv_fifo_wr_en),
	.packet_en(),
	.aux_data_in(axdin),
	.aux_wr_en(ax_recv_wr_en)
);
wire axempty,axfull;
reg ax_recv_rd_en;

afifo25 afifo24_recv (
    .Data(axdin),
    .WrClock(sys_clk),
    .RdClock(fifo_clk),
    .WrEn(ax_recv_wr_en),
    .RdEn(ax_recv_rd_en),
    .Reset(sys_rst),
    .RPReset(sys_rst),
    .Q(axdout),
    .Empty(axempty),
    .Full(axfull)
);

reg [3:0]b_left,bb_left;
reg fl;
reg flg;
reg [5:0]acnt;
reg vblnk;

wire [10:0] ctim = axdout[24:14];
reg initb;
always@(posedge fifo_clk)begin
	if(sys_rst )begin
		init          <= 1'b0;
		initb         <= 1'b0;
		ax_recv_rd_en <= 1'b0;
		b_left        <= 4'd0;
		bb_left       <= 4'd0;
	  acnt          <= 6'd0;
		vblnk         <= 1'b0;
	end else begin
	  bb_left <= b_left;
		initb <= vde;

	  if(~axdout[13])
	    b_left <= axdout[12:9];
		
		/* Intial AUX FIFO Control*/
		if(vde & ~init)begin
		  if({vde,initb} == 2'b10)
			  ax_recv_rd_en <= 1'b1;
		  else begin
			  ax_recv_rd_en <= 1'b0;
				init <= 1'b1;
			end
		end

		if(~vde & ~axempty & init)
			vblnk <= 1'b1;
		else 
			vblnk <= 1'b0;

		if(vblnk)begin
			if(hcnt[10:0] == ctim)begin  // ADE start point, equals Clock Timing
				ax_recv_rd_en <= 1'b1;
				acnt <= 6'd0;
			end

			if(ax_recv_rd_en)begin
				if(acnt == 6'd31 && hcnt[10:0] != ctim)begin
					ax_recv_rd_en <= 1'd0;
					acnt <= acnt + 1;
			  end else if(acnt == 6'd31 && hcnt[10:0] == ctim)begin
				  acnt <= 6'd0;
				end else
				  acnt <= acnt + 1;
			end
		end
	end
end


//
// a clock
//

task waitclock;
begin
	@(posedge sys_clk);
	#1;
end
endtask

//
// Scinario
//

reg [47:0] vrom [0:2024];
reg [11:0] arom [0:2024];
reg [11:0]vcounter = 12'd0;
reg [11:0]acounter = 12'd0;

always@(posedge sys_clk)begin
  if(rd_en)begin
	{tx_data}  <= vrom[vcounter];
	vcounter   <= vcounter + 12'd1;
  end
  {aux2, aux1, aux0}  <= arom[acounter];
  acounter   <= acounter + 12'd1;
 
end


initial begin
	$dumpfile("./test.vcd");
	$dumpvars(0, tb_ether);
	$readmemh("vrequest.mem",vrom);
	$readmemh("arequest.mem",arom);
	sys_rst = 1'b1;
	vcounter = 0;
	acounter = 0;
	
	waitclock;
	waitclock;
	
	sys_rst = 1'b0;
	
	waitclock;
	
	
	#1000000;
	$finish;
end

endmodule
