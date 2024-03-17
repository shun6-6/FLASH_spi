`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/08/03 15:19:28
// Design Name: 
// Module Name: user_data_gen_module
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


module user_data_gen_module#(
    parameter                       P_DATA_WIDTH  = 8  ,
    parameter                       P_SPI_CPOL    = 0  ,
    parameter                       P_SPI_CPHL    = 0  ,
    parameter                       P_READ_DWIDTH = 8  ,
    parameter                       P_OP_LEN      = 32  //操作数据长度
)(
    input                           i_clk                   ,
    input                           i_rst                   ,

    output  [1 :0]                  o_operation_type        ,
    output  [23:0]                  o_operation_addr        ,
    output  [8 :0]                  o_operation_byte_num    ,
    output                          o_operation_valid       ,
    input                           i_operation_ready       ,
    output  [P_DATA_WIDTH - 1 : 0]  o_write_data            ,
    output                          o_write_sop             ,
    output                          o_write_eop             ,
    output                          o_write_valid           ,
    input   [P_DATA_WIDTH - 1 : 0]  i_read_data             ,
    input                           i_read_sop              ,
    input                           i_read_eop              ,
    input                           i_read_valid             
);
/******************************function***************************/
/******************************parameter**************************/
//用户接口操作类型
localparam                      P_CLEAR_TYPE    = 0     ,
                                P_READ_TYPE     = 1     ,
                                P_WRITE_TYPE    = 2     ;

localparam                      P_DATA_NUM      = 256   ;    //max = 256                            
//状态机                                
localparam                      P_ST_IDLE       = 0     ,
                                P_ST_CLEAR      = 1     ,
                                P_ST_WRITE      = 2     ,
                                P_ST_READ       = 3     ;
/******************************port*******************************/
/******************************machine****************************/
reg  [3 :0]                     r_st_cur                ;
reg  [3 :0]                     r_st_nxt                ;
/******************************reg********************************/
reg  [1 :0]                     ro_operation_type       ;
reg  [23:0]                     ro_operation_addr       ;
reg  [8 :0]                     ro_operation_byte_num   ;
reg                             ro_operation_valid      ;
reg  [P_DATA_WIDTH - 1 : 0]     ro_write_data           ;
reg                             ro_write_sop            ;
reg                             ro_write_eop            ;
reg                             ro_write_valid          ;
reg  [P_DATA_WIDTH - 1 : 0]     ri_read_data            ;
reg                             ri_read_sop             ;
reg                             ri_read_eop             ;
reg                             ri_read_valid           ;
reg                             ri_operation_ready_1d   ;
reg                             r_op_active             ;
reg  [15:0]                     r_write_cnt             ;
/******************************wire*******************************/
wire                            w_op_active             ;
wire                            w_operation_ready_pos   ;
/******************************component**************************/
/******************************assign*****************************/
assign o_operation_type     =   ro_operation_type       ;
assign o_operation_addr     =   ro_operation_addr       ;
assign o_operation_byte_num =   ro_operation_byte_num   ;
assign o_operation_valid    =   ro_operation_valid      ;
assign o_write_data         =   ro_write_data           ;
assign o_write_sop          =   ro_write_sop            ;
assign o_write_eop          =   ro_write_eop            ;
assign o_write_valid        =   ro_write_valid          ;

assign w_op_active           = i_operation_ready & o_operation_valid     ;
assign w_operation_ready_pos = i_operation_ready & !ri_operation_ready_1d;
/******************************always*****************************/
always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        r_st_cur <= P_ST_IDLE;
    else
        r_st_cur <= r_st_nxt;
end

always @(*)begin
    case (r_st_cur)
        P_ST_IDLE    :  r_st_nxt = P_ST_CLEAR;
        P_ST_CLEAR   :  r_st_nxt = w_operation_ready_pos ? P_ST_WRITE : P_ST_CLEAR; 
        P_ST_WRITE   :  r_st_nxt = w_operation_ready_pos ? P_ST_READ  : P_ST_WRITE;
        P_ST_READ    :  r_st_nxt = w_operation_ready_pos ? P_ST_IDLE  : P_ST_READ;
        default      :  r_st_nxt = P_ST_IDLE;
    endcase
end

always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        ro_operation_valid <= 'd0;
    else if(w_op_active)
        ro_operation_valid <= 'd0;
    else if(r_st_cur != P_ST_CLEAR && r_st_nxt == P_ST_CLEAR)
        ro_operation_valid <= 'd1;
    else if(r_st_cur != P_ST_WRITE && r_st_nxt == P_ST_WRITE)
        ro_operation_valid <= 'd1;
    else if(r_st_cur != P_ST_READ && r_st_nxt == P_ST_READ)
        ro_operation_valid <= 'd1;
    else
        ro_operation_valid <= ro_operation_valid;
end

always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)begin
        ro_operation_type     <= 'd0;
        ro_operation_addr     <= 'd0;
        ro_operation_byte_num <= 'd0;
    end
    else if(r_st_nxt == P_CLEAR_TYPE)begin
        ro_operation_type     <= P_CLEAR_TYPE;
        ro_operation_addr     <= 'd0;
        ro_operation_byte_num <= 'd0;
    end
    else if(r_st_nxt == P_ST_WRITE)begin
        ro_operation_type     <= P_WRITE_TYPE;
        ro_operation_addr     <= 'd0;
        ro_operation_byte_num <= P_DATA_NUM;
    end
    else if(r_st_nxt == P_ST_READ)begin
        ro_operation_type     <= P_READ_TYPE;
        ro_operation_addr     <= 'd0;
        ro_operation_byte_num <= P_DATA_NUM;
    end
    else begin
        ro_operation_type     <= ro_operation_type    ;
        ro_operation_addr     <= ro_operation_addr    ;
        ro_operation_byte_num <= ro_operation_byte_num;
    end
end

always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        ri_operation_ready_1d <= 'd0;
    else
        ri_operation_ready_1d <= i_operation_ready;
end

always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        r_write_cnt <= 'd0;
    else if(r_write_cnt == P_DATA_NUM-1)
        r_write_cnt <= 'd0;
    else if((r_op_active || r_write_cnt) && r_st_cur == P_ST_WRITE)
        r_write_cnt <= r_write_cnt + 1;
    else
        r_write_cnt <= r_write_cnt;
end

always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        ro_write_data <= 'd0;
    else if(ro_write_valid && ro_write_data < 255)
        ro_write_data <= ro_write_data + 1;
    else
        ro_write_data <= 'd0;
end

always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        r_op_active <= 'd0;
    else
        r_op_active <= w_op_active;
end

always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        ro_write_sop <= 'd0;
    else if(w_op_active && r_st_cur == P_ST_WRITE)
        ro_write_sop <= 'd1;
    else
        ro_write_sop <= 'd0;
end

always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        ro_write_eop <= 'd0;
    else if(r_write_cnt == P_DATA_NUM-2 && ro_write_valid)
        ro_write_eop <= 'd1;
    else
        ro_write_eop <= 'd0;
end

always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)
        ro_write_valid <= 'd0;
    else if(ro_write_eop)
        ro_write_valid <= 'd0;
    else if(w_op_active && r_st_cur == P_ST_WRITE)
        ro_write_valid <= 'd1;
    else
        ro_write_valid <= ro_write_valid;
end

endmodule
