`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/08/02 21:50:28
// Design Name: 
// Module Name: spi_top
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


module spi_top#(
    parameter       P_DATA_WIDTH  = 8   ,
    parameter       P_SPI_CPOL    = 0   ,
    parameter       P_SPI_CPHL    = 0   ,
    parameter       P_READ_DWIDTH = 8   ,
    parameter       P_OP_LEN      = 32   //操作数据长度
)(
    input           clk                 ,
    output          o_spi_cs            ,
    output          o_spi_clk           ,
    output          o_spi_mosi          ,
    input           i_spi_miso           
    );

wire    w_clk_5Mhz  ;
wire    w_5Mhz_lock ;
wire    w_5Mhz_rst  ;

assign w_5Mhz_rst = ~w_5Mhz_lock;

wire [1 :0]                   w_operation_type     ;
wire [23:0]                   w_operation_addr     ;
wire [8 :0]                   w_operation_byte_num ;
wire                          w_operation_valid    ;
wire                          w_operation_ready    ;
wire [P_DATA_WIDTH - 1 : 0]   w_write_data         ;
wire                          w_write_sop          ;
wire                          w_write_eop          ;
wire                          w_write_valid        ;
wire [P_DATA_WIDTH - 1 : 0]   w_read_data          ;
wire                          w_read_sop           ;
wire                          w_read_eop           ;
wire                          w_read_valid         ;


clk_pll_50mhz clk_pll_50mhz_u
(
    .clk_out1               (w_clk_5Mhz ),    
    .locked                 (w_5Mhz_lock ),       
    .clk_in1                (clk        )    
);

Flash_drive#(
    .P_DATA_WIDTH           (8 ) ,
    .P_SPI_CPOL             (0 ) ,
    .P_SPI_CPHL             (0 ) ,
    .P_READ_DWIDTH          (8 ) ,
    .P_OP_LEN               (32)  //操作数据长度
)Flash_drive_u
(
    .i_clk                  (w_clk_5Mhz ),
    .i_rst                  (w_5Mhz_rst ), 

    .i_operation_type       (w_operation_type    ),
    .i_operation_addr       (w_operation_addr    ),
    .i_operation_byte_num   (w_operation_byte_num),
    .i_operation_valid      (w_operation_valid   ),
    .o_operation_ready      (w_operation_ready   ),
    .i_write_data           (w_write_data        ),
    .i_write_sop            (w_write_sop         ),
    .i_write_eop            (w_write_eop         ),
    .i_write_valid          (w_write_valid       ),
    .o_read_data            (w_read_data         ),
    .o_read_sop             (w_read_sop          ),
    .o_read_eop             (w_read_eop          ),
    .o_read_valid           (w_read_valid        ),   

    .o_spi_cs               (o_spi_cs  ),
    .o_spi_clk              (o_spi_clk ),
    .o_spi_mosi             (o_spi_mosi),
    .i_spi_miso             (i_spi_miso) 
);

user_data_gen_module#(
    .P_DATA_WIDTH  (8 ) ,
    .P_SPI_CPOL    (0 ) ,
    .P_SPI_CPHL    (0 ) ,
    .P_READ_DWIDTH (8 ) ,
    .P_OP_LEN      (32)  //操作数据长度
)user_data_gen_module_u
(
    .i_clk                   (w_clk_5Mhz),
    .i_rst                   (w_5Mhz_rst),

    .o_operation_type        (w_operation_type    ),
    .o_operation_addr        (w_operation_addr    ),
    .o_operation_byte_num    (w_operation_byte_num),
    .o_operation_valid       (w_operation_valid   ),
    .i_operation_ready       (w_operation_ready   ),
    .o_write_data            (w_write_data        ),
    .o_write_sop             (w_write_sop         ),
    .o_write_eop             (w_write_eop         ),
    .o_write_valid           (w_write_valid       ),
    .i_read_data             (w_read_data         ),
    .i_read_sop              (w_read_sop          ),
    .i_read_eop              (w_read_eop          ),
    .i_read_valid            (w_read_valid        ) 
);
endmodule
