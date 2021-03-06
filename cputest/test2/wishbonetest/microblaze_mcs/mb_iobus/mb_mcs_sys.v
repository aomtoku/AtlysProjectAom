`timescale 1ns / 1ps
//*****************************************************************************
// File Name            : mb.v
//-----------------------------------------------------------------------------
// Function             : MicroBlaze MAC system 
//                        
//-----------------------------------------------------------------------------
// Designer             : yokomizo 
//-----------------------------------------------------------------------------
// History
// -.-- 2013/02/26
//*****************************************************************************

module mb_mcs_sys(  Clk, Reset, UART_Rx, UART_Tx,led,dip_sw
    );

  input  Clk;      //input clock 100MHz
  input  Reset;    //reset Hi=reset
  input  UART_Rx;  //UART rx 115200bps
  output UART_Tx; //UART tx 115200bps
  output [3 : 0] led;   //led Hi=on
  input  [3 : 0] dip_sw; //input dip_sw
  // 
  parameter p_reg_addr_low =  32'hC0000000;
  parameter p_reg_addr_hi  =  32'hC0000007;
  parameter p_bram_addr_low = 32'hC0001000;
  parameter p_bram_addr_hi  = 32'hC00017FF;
  //IO Bus
  wire IO_Addr_Strobe;
  wire IO_Read_Strobe;
  wire IO_Write_Strobe;
  wire [31 : 0] IO_Read_Data;
  wire [31 : 0] IO_Read_Data_reg;
  wire [31 : 0] IO_Read_Data_bram;
  wire [31 : 0] IO_Address;
  wire [3 : 0]  IO_Byte_Enable;
  wire [31 : 0] IO_Write_Data;
  wire IO_Ready;
  wire IO_Ready_reg;
  wire IO_Ready_bram;
  wire iobus_reg_sel;
  wire iobus_bram_sel;   
  //timmer
  wire FIT1_Interrupt;
  wire FIT1_Toggle;    
  wire PIT1_Interrupt; 
  wire PIT1_Toggle; 
  //GPO   
  wire [31 : 0] GPO1;
  wire [31 : 0] GPI1;
  //GPI
  wire GPI1_Interrupt;
  //Interrupt controller
  wire INTC_Interrupt;
  wire INTC_IRQ;
  //iobus_reg
  wire [31:0] data_in;
  wire [3:0]  data_in_en;
  wire [31:0] data_out;
  wire [3:0]  data_out_en;
  //user_module
  wire [7:0] chk_data; 
  //block ram port-B
  wire  [3:0]web;
  wire  [8 : 0] addrb;
  wire  [31 : 0] dinb;
  wire  [31 : 0] doutb;

  //LED制御
  assign led = {data_out[1:0],GPO1[1:0]};
  //信号接続
  assign GPI1 = {28'h0000000,dip_sw};
  assign data_in = data_out;
  assign data_in_en = data_out_en; 
  assign chk_data = data_out[7:0];  
  assign INTC_Interrupt = 1'b0;  

  //周辺回路選択信号
  assign iobus_reg_sel  = ((IO_Address>=p_reg_addr_low)&&(IO_Address<=p_reg_addr_hi))? 1'b1:1'b0;
  assign iobus_bram_sel = ((IO_Address>=p_bram_addr_low)&&(IO_Address<=p_bram_addr_hi))? 1'b1:1'b0;   
  //読出しデータの選択       
  assign IO_Read_Data = (iobus_reg_sel==1'b1)?  IO_Read_Data_reg:
                        (iobus_bram_sel==1'b1)? IO_Read_Data_bram:
                                                32'h00000000;
  //Ready信号の選択  
  assign IO_Ready =    (iobus_reg_sel==1'b1)?  IO_Ready_reg:
                       (iobus_bram_sel==1'b1)? IO_Ready_bram:
                                               1'b0;

//Microblaze MCSのインスタンス
mb_mcs mcs_0 (
  .Clk(Clk), // input Clk
  .Reset(Reset), // input Reset
  .IO_Addr_Strobe(IO_Addr_Strobe), // output IO_Addr_Strobe
  .IO_Read_Strobe(IO_Read_Strobe), // output IO_Read_Strobe
  .IO_Write_Strobe(IO_Write_Strobe), // output IO_Write_Strobe
  .IO_Address(IO_Address), // output [31 : 0] IO_Address
  .IO_Byte_Enable(IO_Byte_Enable), // output [3 : 0] IO_Byte_Enable
  .IO_Write_Data(IO_Write_Data), // output [31 : 0] IO_Write_Data
  .IO_Read_Data(IO_Read_Data), // input [31 : 0] IO_Read_Data
  .IO_Ready(IO_Ready), // input IO_Ready
  .UART_Rx(UART_Rx), // input UART_Rx
  .UART_Tx(UART_Tx), // output UART_Tx
  .FIT1_Interrupt(FIT1_Interrupt), // output FIT1_Interrupt
  .FIT1_Toggle(FIT1_Toggle), // output FIT1_Toggle
  .PIT1_Interrupt(PIT1_Interrupt), // output PIT1_Interrupt
  .PIT1_Toggle(PIT1_Toggle), // output PIT1_Toggle
  .GPO1(GPO1), // output [31 : 0] GPO1
  .GPI1(GPI1), // input [31 : 0] GPI1
  .GPI1_Interrupt(GPI1_Interrupt), // output GPI1_Interrupt
  .INTC_Interrupt(INTC_Interrupt), // input [0 : 0] INTC_Interrupt
  .INTC_IRQ(INTC_IRQ) // output INTC_IRQ
); 
 
//設定レジスタのインスタンス
iobus_reg
#(p_reg_addr_low, p_reg_addr_hi)
iobus_reg_0 (
  .Clk(Clk), // input Clk
  .Reset(Reset), // input Reset
  .IO_Addr_Strobe(IO_Addr_Strobe), // output IO_Addr_Strobe
  .IO_Read_Strobe(IO_Read_Strobe), // output IO_Read_Strobe
  .IO_Write_Strobe(IO_Write_Strobe), // output IO_Write_Strobe
  .IO_Address(IO_Address), // output [31 : 0] IO_Address
  .IO_Byte_Enable(IO_Byte_Enable), // output [3 : 0] IO_Byte_Enable
  .IO_Write_Data(IO_Write_Data), // output [31 : 0] IO_Write_Data
  .IO_Read_Data(IO_Read_Data_reg), // input [31 : 0] IO_Read_Data
  .IO_Ready(IO_Ready_reg), // input IO_Ready
  //input 
  .data_in(data_in), // input data
  .data_in_en(data_in_en), // input data enable
  //output 
  .data_out(data_out), // output data
  .data_out_en(data_out_en) // output data enable
);

//ブロックRAMインターフェースのインスタンス
iobus_bram
 #(p_bram_addr_low, p_bram_addr_hi)
iobus_bram_0 (
  .Clk(Clk), // input Clk
  .Reset(Reset), // input Reset
  .IO_Addr_Strobe(IO_Addr_Strobe), // output IO_Addr_Strobe
  .IO_Read_Strobe(IO_Read_Strobe), // output IO_Read_Strobe
  .IO_Write_Strobe(IO_Write_Strobe), // output IO_Write_Strobe
  .IO_Address(IO_Address), // output [31 : 0] IO_Address
  .IO_Byte_Enable(IO_Byte_Enable), // output [3 : 0] IO_Byte_Enable
  .IO_Write_Data(IO_Write_Data), // output [31 : 0] IO_Write_Data
  .IO_Read_Data(IO_Read_Data_bram), // input [31 : 0] IO_Read_Data
  .IO_Ready(IO_Ready_bram), // input IO_Ready
  //BRAM Port-B                  
  .clkb(Clk), // input clkb
  .web(web), // input [3:0]web
  .addrb(addrb), // input [8 : 0] addrb
  .dinb(dinb), // input [31 : 0] dinb
  .doutb(doutb) // output [31 : 0] doutb
);
   
user_module user_module_0 (
  .Clk(Clk), // input Clk
  .Reset(Reset), // input Reset
  .chk_data(chk_data),
  //BRAM Port-B                  
  .clk(clkb), // input clkb
  .we(web), // input[3:0]web
  .addr(addrb), // input [8 : 0] addrb
  .dout(dinb) // output [31 : 0] doutb
);

   
endmodule
