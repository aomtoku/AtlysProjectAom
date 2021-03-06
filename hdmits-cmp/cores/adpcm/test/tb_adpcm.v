`timescale 1ns / 1ps

module tb_adpcm();


//
// System Clock 125MHz
//
reg sys_clk;
initial sys_clk = 1'b0;
always #6.74 sys_clk = ~sys_clk;

//
// Test Bench
//
reg sys_rst;
reg en; // ever or odd bit
wire [15:0]in;
wire [15:0]out;
wire oen;
wire eo;

en_adpcm test(
  .clk(sys_clk),
  .rst(sys_rst),
  .in_en(en),
  .din(in),
  .out_en(oen),
  .dout(out),
	.eo(eo)
);

wire [15:0]ddout = (eo) ? out : {8'd0,out[11:8],out[3:0]};

wire toen;
wire [15:0]dout;
dc_adpcm test1(
  .clk(sys_clk),     // System clock
  .rst(sys_rst),     // System Reset 
  .in_en(oen),   // Input Enable Signal
  .din(ddout),     // Encoded Data(input)
  .out_en(toen),  // Output Enable signal 1 clock sycle delay
  .dout(dout)     // Decoded Data(output)
);

//
// a clock
//
task waitclock;
begin
	@(posedge sys_clk);
	#1;
end
endtask

reg [7:0]cnt;
always@(posedge sys_clk)
  if(sys_rst)begin
		en <= 1'd0;
		cnt <= 8'd0;
	end else begin
	  if(cnt == 8'd15)
			cnt <= 8'd0;
		else
			cnt <= cnt + 8'd1;

		if(cnt == 8'd1)
			en <= ~en;

	end
		

reg [7:0]a,b;
assign in = {a,b};
always @ (posedge sys_clk) begin
  if(sys_rst)begin
    a <= 8'd0;
    b <= 8'd0;
  end else begin
    a <= a + 8'd18;
    b <= b + 8'd34;
  end
end

//
// Scinario
//

initial begin
	$dumpfile("./test.vcd");
	$dumpvars(0, tb_adpcm);
	sys_rst = 1'b1;

	waitclock;
	waitclock;

	sys_rst = 1'b0;

	waitclock;


	#100000;
	$finish;
end

endmodule
