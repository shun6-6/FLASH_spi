`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/07/29 10:15:16
// Design Name: 
// Module Name: spi_drive
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module spi_drive#(
    parameter                      P_DATA_WIDTH  = 8  ,
    parameter                      P_SPI_CPOL    = 0  ,
    parameter                      P_SPI_CPHL    = 0  ,
    parameter                      P_READ_DWIDTH = 8  ,
    parameter                      P_OP_LEN      = 32  //操作数据长度
)( 
    input                          i_clk              ,
    input                          i_rst              ,
                               
    output                         o_spi_cs           ,//spi片选信号
    output                         o_spi_clk          ,//spi时钟线
    output                         o_spi_mosi         ,//spi主机输出
    input                          i_spi_miso         ,//spi主机输入
 
    input  [P_OP_LEN - 1 : 0]      i_user_op_data     ,//操作数据(数据8+地址24)
    input  [1:0]                   i_user_op_type     ,//操作类型(读写数据，读写指令)
    input  [15:0]                  i_user_op_len      ,//操作数据长度(读写数据8+24，指令8)
    input  [15:0]                  i_user_clk_len     ,//时钟周期，读写数据时为8+24+8*字节数
    input                          i_user_op_valid    ,//用户数据有效信号
    output                         o_user_op_ready    ,//主机准备信号
 
    input  [P_DATA_WIDTH - 1 : 0]  i_user_write_data  ,//写数据
    output                         o_user_write_req   ,//写数据请求
 
    output [P_READ_DWIDTH - 1 : 0] o_user_read_data   ,//读数据
    output                         o_user_read_valid   //读数据有效

    );
/******************************function***************************/
/******************************parameter**************************/
localparam P_OP_INS   = 0,
           P_OP_READ  = 1,
           P_OP_WRITE = 2;
/******************************port*******************************/
/******************************machine****************************/
/******************************reg********************************/
reg                          ro_spi_cs            ;
reg                          ro_spi_clk           ;
reg                          ro_spi_mosi          ;
reg                          ro_user_ready        ;
reg  [P_OP_LEN - 1 : 0]      r_user_op_data       ;
reg  [1:0]                   r_user_op_type       ;
reg  [15:0]                  r_user_op_len        ;
reg  [15:0]                  r_user_clk_len       ;
reg                          r_run                ;
reg                          r_run_1d             ;
reg  [15:0]                  r_cnt                ;
reg                          r_spi_cnt            ;
reg                          ro_user_write_req    ;
reg                          ro_user_write_req_1d ;
reg  [15:0]                  r_write_cnt          ;
reg  [P_DATA_WIDTH - 1 : 0]  r_user_write_data    ;
reg  [P_READ_DWIDTH - 1 : 0] ro_user_read_data    ;
reg                          ro_user_read_valid   ;
reg  [15:0]                  r_read_cnt           ;
/******************************wire*******************************/
wire                         w_tx_active          ;
/******************************component**************************/
/******************************assign*****************************/
assign o_spi_cs          = ro_spi_cs                  ;
assign o_spi_clk         = ro_spi_clk                 ;
assign o_spi_mosi        = ro_spi_mosi                ;
assign o_user_op_ready   = ro_user_ready              ;
assign o_user_read_data  = ro_user_read_data          ; 
assign o_user_write_req  = ro_user_write_req          ;
assign o_user_read_valid = ro_user_read_valid         ; 

assign w_tx_active       = i_user_op_valid & o_user_op_ready;
/******************************always*****************************/
//控制准备信号
always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        ro_user_ready <= 'd1;
    else if(r_run_1d && !r_run)
        ro_user_ready <= 'd1;
    else if(w_tx_active)
        ro_user_ready <= 'd0;
    else
        ro_user_ready <= ro_user_ready;
end
//寄存控制指令信号
always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)begin
        r_user_op_type <= 'd0;
        r_user_op_len  <= 'd0;
        r_user_clk_len <= 'd0;
    end
    else if(w_tx_active)begin
        r_user_op_type <= i_user_op_type;
        r_user_op_len  <= i_user_op_len ;
        r_user_clk_len <= i_user_clk_len;        
    end
    else begin
        r_user_op_type <= r_user_op_type;
        r_user_op_len  <= r_user_op_len ;
        r_user_clk_len <= r_user_clk_len;        
    end
end
//指令数据
always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        r_user_op_data <= 'd0;
    else if(w_tx_active)
        r_user_op_data <= i_user_op_data;//握手成功后寄存操作数据      
    else if(r_spi_cnt)
        r_user_op_data <= r_user_op_data << 1;//随后开始移位输出操作数据
    else 
        r_user_op_data <= r_user_op_data;       
end
//总线有效指示信号，高有效
always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        r_run <= 'd0;
    else if(r_cnt == r_user_clk_len - 1 && r_spi_cnt)
        r_run <= 'd0;
    else if(w_tx_active)
        r_run <= 'd1;
    else
        r_run <= r_run;
end
always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        r_run_1d <= 'd0;
    else
        r_run_1d <= r_run;
end
//spi时钟周期计数器
always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        r_cnt <= 'd0;
    else if(r_cnt == r_user_clk_len - 1 && r_spi_cnt)
        r_cnt <= 'd0;
    else if(r_spi_cnt)
        r_cnt <= r_cnt + 1;
    else
        r_cnt <= r_cnt;
end
//spi时钟计数器
always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        r_spi_cnt <= 'd0;
    else if(r_run)
        r_spi_cnt <= r_spi_cnt + 1;
    else
        r_spi_cnt <= r_spi_cnt;
end
//spi时钟信号
always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        ro_spi_clk <= P_SPI_CPOL;
    else if(r_run)
        ro_spi_clk <= ~ro_spi_clk;
    else
        ro_spi_clk <= P_SPI_CPOL;
end
//spi片选信号
always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        ro_spi_cs <= 'd1;
    else if(w_tx_active)
        ro_spi_cs <= 'd0;
    else if(r_run_1d && !r_run)
        ro_spi_cs <= 'd1;
    else
        ro_spi_cs <= ro_spi_cs;
end
//spi输出引脚mosi
always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        ro_spi_mosi <= 'd0;
    else if(w_tx_active)
        ro_spi_mosi <= i_user_op_data[P_OP_LEN-1];//输出操作数据最高位
    else if(r_spi_cnt && r_cnt < r_user_op_len - 1)//?
        ro_spi_mosi <= r_user_op_data[P_OP_LEN-2];//输出操作数据次高位
    else if(r_user_op_type == P_OP_WRITE && r_spi_cnt)//串行输出写数据
        ro_spi_mosi <= r_user_write_data[P_DATA_WIDTH - 1];
    else
        ro_spi_mosi <= ro_spi_mosi;
end
//写数据请求    
always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        ro_user_write_req <= 'd0;
    else if(r_cnt >= r_user_clk_len - 5)//保证不会多出一次数据请求
        ro_user_write_req <= 'd0;
    else if((r_cnt == 30 && !r_spi_cnt) || (r_write_cnt == 15) && r_user_op_type == P_OP_WRITE)
        ro_user_write_req <= 'd1;
    else
        ro_user_write_req <= 'd0;
end
always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        ro_user_write_req_1d <= 'd0;
    else
        ro_user_write_req_1d <= ro_user_write_req;
end
always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        r_write_cnt <= 'd0;
    else if(r_write_cnt == 15 || ro_spi_cs)
        r_write_cnt <= 'd0;
    else if(ro_user_write_req || r_write_cnt)
        r_write_cnt <= r_write_cnt + 1;
    else
        r_write_cnt <= r_write_cnt;
end
//输入数据寄存
always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        r_user_write_data <= 'd0;
    else if(!ro_user_write_req & ro_user_write_req_1d)
        r_user_write_data <= i_user_write_data;
    else if(r_spi_cnt)
        r_user_write_data <= r_user_write_data << 1;
    else
        r_user_write_data <= r_user_write_data;
end
//输出信号
always @(posedge ro_spi_clk or posedge i_rst)begin
    if(i_rst)
        ro_user_read_data <= 'd0;
    else if(r_cnt > r_user_op_len - 1)
        ro_user_read_data <= {ro_user_read_data[P_DATA_WIDTH-2:0],i_spi_miso};
    else
        ro_user_read_data <= ro_user_read_data;
end

always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        r_read_cnt <= 'd0;
    else if(r_read_cnt == P_DATA_WIDTH - 0 || ro_spi_cs)
        r_read_cnt <= 'd0;
    else if(r_cnt > r_user_op_len - 1 && r_spi_cnt && r_user_op_type == P_OP_READ)
        r_read_cnt <= r_read_cnt + 1;
    else
        r_read_cnt <= r_read_cnt;
end
//输出有效信号
always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        ro_user_read_valid <= 'd0;
    else if(r_user_op_type == P_OP_READ && r_read_cnt ==  P_DATA_WIDTH - 1 && r_spi_cnt)
        ro_user_read_valid <= 'd1;
    else
        ro_user_read_valid <= 'd0;
end

endmodule
