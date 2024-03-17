`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/08/02 08:46:16
// Design Name: 
// Module Name: Flash_drive
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


module Flash_drive#(
    parameter                      P_DATA_WIDTH  = 8  ,
    parameter                      P_SPI_CPOL    = 0  ,
    parameter                      P_SPI_CPHL    = 0  ,
    parameter                      P_READ_DWIDTH = 8  ,
    parameter                      P_OP_LEN      = 32  
)(
    input       i_clk                                       ,
    input       i_rst                                       ,
    /*--------user接口--------*/ 
    input  [1 :0]                   i_operation_type        ,
    input  [23:0]                   i_operation_addr        ,
    input  [8 :0]                   i_operation_byte_num    ,
    input                           i_operation_valid       ,
    output                          o_operation_ready       ,
    input  [P_DATA_WIDTH - 1 : 0]   i_write_data            ,
    input                           i_write_sop             ,
    input                           i_write_eop             ,
    input                           i_write_valid           ,
    output [P_DATA_WIDTH - 1 : 0]   o_read_data             ,
    output                          o_read_sop              ,
    output                          o_read_eop              ,
    output                          o_read_valid            ,   
    /*--------spi接口--------*/
    output                          o_spi_cs                ,
    output                          o_spi_clk               ,
    output                          o_spi_mosi              ,
    input                           i_spi_miso              
);

wire [P_OP_LEN - 1 : 0]         w_user_op_data      ;
wire [1:0]                      w_user_op_type      ;
wire [15:0]                     w_user_op_len       ;
wire [15:0]                     w_user_clk_len      ;
wire                            w_user_op_valid     ;
wire                            w_user_op_ready     ;
wire [P_DATA_WIDTH - 1 : 0]     w_user_write_data   ;
wire                            w_user_write_req    ;
wire [P_READ_DWIDTH - 1 : 0]    w_user_read_data    ;
wire                            w_user_read_valid   ;

Flash_ctrl#(
    .P_DATA_WIDTH  (8 )      ,
    .P_SPI_CPOL    (0 )      ,
    .P_SPI_CPHL    (0 )      ,
    .P_READ_DWIDTH (8 )      ,
    .P_OP_LEN      (32)       
)Flash_ctrl_u
(      
    .i_clk                      (i_clk               ),
    .i_rst                      (i_rst               ),
/*--------user--------*/       
    .i_operation_type           (i_operation_type    ),
    .i_operation_addr           (i_operation_addr    ),
    .i_operation_byte_num       (i_operation_byte_num),
    .i_operation_valid          (i_operation_valid   ),
    .o_operation_ready          (o_operation_ready   ),

    .i_write_data               (i_write_data        ),
    .i_write_sop                (i_write_sop         ),
    .i_write_eop                (i_write_eop         ),
    .i_write_valid              (i_write_valid       ),
    .o_read_data                (o_read_data         ),
    .o_read_sop                 (o_read_sop          ),
    .o_read_eop                 (o_read_eop          ),
    .o_read_valid               (o_read_valid        ),
/*--------spi_drive--------*/                
    .o_user_op_data             (w_user_op_data      ),
    .o_user_op_type             (w_user_op_type      ),
    .o_user_op_len              (w_user_op_len       ),
    .o_user_clk_len             (w_user_clk_len      ),
    .o_user_op_valid            (w_user_op_valid     ),
    .i_user_op_ready            (w_user_op_ready     ),
    .o_user_write_data          (w_user_write_data   ),
    .i_user_write_req           (w_user_write_req    ),
    .i_user_read_data           (w_user_read_data    ),
    .i_user_read_valid          (w_user_read_valid   ) 
    );

spi_drive#(
    .P_DATA_WIDTH               (8 ),
    .P_SPI_CPOL                 (0 ),
    .P_SPI_CPHL                 (0 ),
    .P_READ_DWIDTH              (8 ),
    .P_OP_LEN                   (32)
)spi_drive_u            
(           
    .i_clk                      (i_clk            ),
    .i_rst                      (i_rst            ),

    .o_spi_cs                   (o_spi_cs         ),
    .o_spi_clk                  (o_spi_clk        ),
    .o_spi_mosi                 (o_spi_mosi       ),
    .i_spi_miso                 (i_spi_miso       ),

    .i_user_op_data             (w_user_op_data   ),
    .i_user_op_type             (w_user_op_type   ),
    .i_user_op_len              (w_user_op_len    ),
    .i_user_clk_len             (w_user_clk_len   ),
    .i_user_op_valid            (w_user_op_valid  ),
    .o_user_op_ready            (w_user_op_ready  ),
    .i_user_write_data          (w_user_write_data),
    .o_user_write_req           (w_user_write_req ),
    .o_user_read_data           (w_user_read_data ),
    .o_user_read_valid          (w_user_read_valid)

    );

endmodule
