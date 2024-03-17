`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/08/02 08:45:38
// Design Name: 
// Module Name: Flash_ctrl
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


module Flash_ctrl#(
    parameter                       P_DATA_WIDTH  = 8       ,//数据位宽
    parameter                       P_SPI_CPOL    = 0       ,//spi时钟极性:0/1表示空闲时钟电平为0/1
    parameter                       P_SPI_CPHL    = 0       ,//spi时钟相位:0/1表示数据采集沿为时钟第1/2跳变沿
    parameter                       P_READ_DWIDTH = 8       ,//读数据位宽
    parameter                       P_OP_LEN      = 32       //操作数据长度
)(      
    input                           i_clk                   ,
    input                           i_rst                   ,
    /*--------用户接口--------*/        
    input  [1 :0]                   i_operation_type        ,//操作类型 1:read 2:write
    input  [23:0]                   i_operation_addr        ,//操作地址
    input  [8 :0]                   i_operation_byte_num    ,//max write 256 byte
    input                           i_operation_valid       ,//操作有效信号
    output                          o_operation_ready       ,//操作准备信号

    input  [P_DATA_WIDTH - 1 : 0]   i_write_data            ,//写数据
    input                           i_write_sop             ,//写数据-开始信号
    input                           i_write_eop             ,//写数据-结束信号
    input                           i_write_valid           ,//写数据有效

    output [P_DATA_WIDTH - 1 : 0]   o_read_data             ,//读数据
    output                          o_read_sop              ,//读数据-开始信号
    output                          o_read_eop              ,//读数据-结束信号
    output                          o_read_valid            ,//读数据有效
    /*--------驱动接口--------*/            
    output [P_OP_LEN - 1 : 0]       o_user_op_data          ,//操作数据(数据8+地址24)
    output [1:0]                    o_user_op_type          ,//操作类型(读写数据，读写指令)
    output [15:0]                   o_user_op_len           ,//操作数据长度(读写数据8+24，指令8)
    output [15:0]                   o_user_clk_len          ,//时钟周期，读写数据时为8+24+8*字节数
    output                          o_user_op_valid         ,//用户数据有效信号
    input                           i_user_op_ready         ,//驱动准备信号

    output [P_DATA_WIDTH - 1 : 0]   o_user_write_data       ,//写数据
    input                           i_user_write_req        ,//写数据请求

    input  [P_READ_DWIDTH - 1 : 0]  i_user_read_data        ,//读数据
    input                           i_user_read_valid        //读数据有效
    );
/******************************function***************************/
/******************************parameter**************************/
//用户接口操作类型
localparam  P_CLEAR_TYPE   = 0,
            P_READ_TYPE    = 1,
            P_WRITE_TYPE   = 2;
//SPI驱动操作类型 
localparam  P_OP_INS       = 0,
            P_OP_READ      = 1,
            P_OP_WRITE     = 2;
//FSM 
localparam  P_ST_IDLE      = 11'b00000000001,//空闲状态，握手成功后进入运行状态
            P_ST_RUN       = 11'b00000000010,//运行状态，如果是读指令则进入读数据状态，否则为擦除或者写数据指令，都需要先进入写使能状态
            P_ST_W_EN      = 11'b00000000100,//写使能状态，若为写数据指令则进入写指令状态，否则进入擦除状态
            P_ST_W_INS     = 11'b00000001000,//写数据指令状态
            P_ST_W_DATA    = 11'b00000010000,//写数据状态
            P_ST_R_INS     = 11'b00000100000,//读数据指令状态
            P_ST_R_DATA    = 11'b00001000000,//读数据状态
            P_ST_CLEAR     = 11'b00010000000,//擦除状态
            P_ST_BUSY      = 11'b00100000000,//读忙状态寄存器
            P_ST_BUSY_CHK  = 11'b01000000000,//检查返回的忙状态寄存器状态，若为忙则进入P_ST_BUSY_WAIT状态，不忙则说明读数据结束，返回空闲状态
            P_ST_BUSY_WAIT = 11'b10000000000;//读忙等待状态，计数256后再次返回P_ST_BUSY读忙状态
/******************************port*******************************/
/******************************machine****************************/
reg  [10:0]                     r_st_cur                ;
reg  [10:0]                     r_st_nxt                ;
reg  [15:0]                     r_st_cnt                ;
/******************************reg********************************/
reg                             ro_operation_ready      ;
reg                             ro_read_sop             ;
reg                             ro_read_eop             ;
reg                             ro_read_valid           ;
reg  [P_DATA_WIDTH - 1 : 0]     ro_read_data            ;
reg                             r_fifo_rden             ;
reg                             r_fifo_rden_1d          ;
reg                             r_fifo_rden_pos         ;//使能信号上升沿

reg  [1 :0]                     ri_operation_type       ;
reg  [23:0]                     ri_operation_addr       ;
reg  [8 :0]                     ri_operation_byte_num   ;
reg  [P_DATA_WIDTH - 1 : 0]     ri_write_data           ;
reg                             ri_write_sop            ;
reg                             ri_write_eop            ;
reg                             ri_write_valid          ;
reg                             r_fifo_wren             ;

reg  [P_OP_LEN - 1 : 0]         ro_user_op_data         ;
reg  [1:0]                      ro_user_op_type         ;
reg  [15:0]                     ro_user_op_len          ;
reg  [15:0]                     ro_user_clk_len         ;
reg                             ro_user_op_valid        ;
reg  [P_READ_DWIDTH - 1 : 0]    ri_user_read_data       ;
reg                             ri_user_read_valid      ;
reg                             r_fifo_read_empty_1d    ;
/******************************wire*******************************/
wire                            w_user_op_active        ;
wire                            w_spi_op_active         ;
wire                            w_fifo_read_empty       ;
wire [P_READ_DWIDTH - 1 : 0]    w_read_data             ;
/******************************component**************************/
//用户写数据存入此FIFO，spi驱动从此处读取数据然后写入flash
FLASH_DATA_FIFO FLASH_DATA_FIFO_u0 (
  .clk          (i_clk              ), 
  //.srst         (i_rst              ), 
  .din          (ri_write_data      ), 
  .wr_en        (ri_write_valid     ), 
  .rd_en        (i_user_write_req   ), 
  .dout         (o_user_write_data  ), 
  .full         (), 
  .empty        () 
 
);
//spi驱动从flash读出的数据存入此FIFO，用户接口从此处读取数据
FLASH_DATA_FIFO FLASH_DATA_FIFO_u1 (
  .clk          (i_clk              ),
  //.srst         (i_rst              ),
  .din          (ri_user_read_data  ),
  .wr_en        (r_fifo_wren        ),
  .rd_en        (r_fifo_rden        ),
  .dout         (w_read_data        ),
  .full         (),
  .empty        (w_fifo_read_empty  )
);
/******************************assign*****************************/
assign w_user_op_active  = i_operation_valid & o_operation_ready    ;
assign w_spi_op_active   = o_user_op_valid & i_user_op_ready        ;

assign o_operation_ready = ro_operation_ready                       ;
assign o_read_sop        = ro_read_sop                              ;
assign o_read_eop        = ro_read_eop                              ;
assign o_read_valid      = ro_read_valid                            ;
assign o_read_data       = ro_read_data                             ;

assign o_user_op_data    = ro_user_op_data                          ;
assign o_user_op_type    = ro_user_op_type                          ;
assign o_user_op_len     = ro_user_op_len                           ;
assign o_user_clk_len    = ro_user_clk_len                          ;
assign o_user_op_valid   = ro_user_op_valid                         ;
/******************************always*****************************/
always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        r_st_cur <= P_ST_IDLE;
    else
        r_st_cur <= r_st_nxt;
end
always @(*)begin
    case (r_st_cur)
        P_ST_IDLE       : r_st_nxt = w_user_op_active   ? P_ST_RUN      : P_ST_IDLE  ;
        P_ST_RUN        : r_st_nxt = ri_operation_type == P_READ_TYPE ? P_ST_R_INS : P_ST_W_EN;
        P_ST_W_EN       : r_st_nxt = w_spi_op_active    ? 
                                     ri_operation_type == P_WRITE_TYPE ? P_ST_W_INS : P_ST_CLEAR
                                    : P_ST_W_EN  ;
        P_ST_W_INS      : r_st_nxt = w_spi_op_active    ? P_ST_W_DATA   : P_ST_W_INS ;
        P_ST_W_DATA     : r_st_nxt = i_user_op_ready    ? P_ST_BUSY     : P_ST_W_DATA;
        P_ST_R_INS      : r_st_nxt = w_spi_op_active    ? P_ST_R_DATA   : P_ST_R_INS ;
        P_ST_R_DATA     : r_st_nxt = i_user_op_ready    ? P_ST_BUSY     : P_ST_R_DATA;
        P_ST_CLEAR      : r_st_nxt = w_spi_op_active    ? P_ST_BUSY     : P_ST_CLEAR ;
        P_ST_BUSY       : r_st_nxt = w_spi_op_active    ? P_ST_BUSY_CHK : P_ST_BUSY  ;      
        P_ST_BUSY_CHK   : r_st_nxt = ri_user_read_valid ? 
                                     ri_user_read_data[0] ? P_ST_BUSY_WAIT : P_ST_IDLE
                                     : P_ST_BUSY_CHK;  
        P_ST_BUSY_WAIT  : r_st_nxt = r_st_cnt == 255    ? P_ST_BUSY     : P_ST_BUSY_WAIT;
        default         : r_st_nxt = P_ST_IDLE;      
    endcase
end
always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        r_st_cnt <= 'd0;
    else if(r_st_cur != r_st_nxt)
        r_st_cnt <= 'd0;
    else
        r_st_cnt <= r_st_cnt + 1;
end
/*--------驱动逻辑--------*/
always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)begin 
        ro_user_op_data  <= 'd0;
        ro_user_op_type  <= 'd0;
        ro_user_op_len   <= 'd0;
        ro_user_clk_len  <= 'd0;
        ro_user_op_valid <= 'd0;
    end
    else if(r_st_cur == P_ST_W_EN)begin                       //发送写使能指令
        ro_user_op_data  <= {8'h06,8'h00,8'h00,8'h00};
        ro_user_op_type  <= P_OP_INS;
        ro_user_op_len   <= 8;
        ro_user_clk_len  <= 8;
        ro_user_op_valid <= 1;
    end
    else if(r_st_cur == P_ST_W_INS)begin                    //发送写数据指令
        ro_user_op_data  <= {8'h02,ri_operation_addr};
        ro_user_op_type  <= P_OP_WRITE;
        ro_user_op_len   <= 32;
        ro_user_clk_len  <= 32 + 8 * ri_operation_byte_num;
        ro_user_op_valid <= 1;
    end
    else if(r_st_cur == P_ST_R_INS)begin                    //发送读数据指令
        ro_user_op_data  <= {8'h03,ri_operation_addr};
        ro_user_op_type  <= P_OP_READ;
        ro_user_op_len   <= 32;
        ro_user_clk_len  <= 32 + 8 * ri_operation_byte_num;
        ro_user_op_valid <= 1;
    end 
    else if(r_st_cur == P_ST_CLEAR)begin                    //发送擦除指令
        ro_user_op_data  <= {8'h20,ri_operation_addr};
        ro_user_op_type  <= P_OP_INS;
        ro_user_op_len   <= 32;
        ro_user_clk_len  <= 32 ;
        ro_user_op_valid <= 1;
    end 
    else if(r_st_cur == P_ST_BUSY)begin                     //发送读状态指令-读busy
        ro_user_op_data  <= {8'h05,24'd0};
        ro_user_op_type  <= P_OP_READ;
        ro_user_op_len   <= 8;
        ro_user_clk_len  <= 16;
        ro_user_op_valid <= 1;
    end
    else begin 
        ro_user_op_data  <= ro_user_op_data ;
        ro_user_op_type  <= ro_user_op_type ;
        ro_user_op_len   <= ro_user_op_len  ;
        ro_user_clk_len  <= ro_user_clk_len ;
        ro_user_op_valid <= 'd0             ;
    end
end

always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)begin 
        ri_user_read_data  <= 'd0;
        ri_user_read_valid <= 'd0;
    end
    else begin
        ri_user_read_data  <= i_user_read_data ;
        ri_user_read_valid <= i_user_read_valid;
    end
end

/*--------用户逻辑--------*/
//输入寄存
always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)begin
        ri_operation_type       <= 'd0;
        ri_operation_addr       <= 'd0;
        ri_operation_byte_num   <= 'd0;
    end
    else if(w_user_op_active)begin
        ri_operation_type      <= i_operation_type     ;
        ri_operation_addr      <= i_operation_addr     ;
        ri_operation_byte_num  <= i_operation_byte_num ;
    end
    else begin
        ri_operation_type      <= ri_operation_type     ;
        ri_operation_addr      <= ri_operation_addr     ;
        ri_operation_byte_num  <= ri_operation_byte_num ;
    end
end

always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        ro_operation_ready <= 'd1;
    else if(r_st_nxt == P_ST_IDLE)
        ro_operation_ready <= 'd1;
    else if(w_user_op_active)
        ro_operation_ready <= 'd0;
    else
        ro_operation_ready <= ro_operation_ready;
end

always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)begin
        ri_write_data  <= 'd0;
        ri_write_sop   <= 'd0;
        ri_write_eop   <= 'd0;
        ri_write_valid <= 'd0;
    end
    else begin
        ri_write_data  <= i_write_data ;
        ri_write_sop   <= i_write_sop  ;
        ri_write_eop   <= i_write_eop  ;
        ri_write_valid <= i_write_valid;
    end
end

always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        r_fifo_rden <= 'd0;
    else if(w_fifo_read_empty)
        r_fifo_rden <= 'd0;
    else if(r_st_cur == P_ST_R_DATA && r_st_nxt != P_ST_R_DATA)
        r_fifo_rden <= 'd1;
    else
        r_fifo_rden <= r_fifo_rden;
end

always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        r_fifo_rden_1d <= 'd0;
    else
        r_fifo_rden_1d <= r_fifo_rden;
end

always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        r_fifo_rden_pos <= 'd0;
    else
        r_fifo_rden_pos <= r_fifo_rden && !r_fifo_rden_1d;
end

always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        r_fifo_read_empty_1d <= 'd0;
    else
        r_fifo_read_empty_1d <= w_fifo_read_empty;
end

always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        ro_read_sop <= 'd0;
    else if(r_fifo_rden_pos)
        ro_read_sop <= 'd1;
    else
        ro_read_sop <= 'd0;
end

always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        ro_read_eop <= 'd0;
    else if(w_fifo_read_empty && !r_fifo_read_empty_1d && ro_read_valid)
        ro_read_eop <= 'd1;
    else
        ro_read_eop <= 'd0;
end

always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        ro_read_valid <= 'd0;
    else if(ro_read_eop)
        ro_read_valid <= 'd0;
    else if(r_fifo_rden_pos)
        ro_read_valid <= 'd1;
    else
        ro_read_valid <= ro_read_valid;
end

always @(posedge i_clk or posedge i_rst) begin
    if(i_rst)
        ro_read_data <= 'd0;
    else    
        ro_read_data <= w_read_data;
end

always @(posedge i_clk or posedge i_rst) begin
    if(i_rst)
        r_fifo_wren <= 'd0;
    else if(r_st_cur == P_ST_R_DATA)
        r_fifo_wren <= i_user_read_valid;
    else    
        r_fifo_wren <= 'd0;
end

endmodule
