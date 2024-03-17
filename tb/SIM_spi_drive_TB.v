`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/07/29 11:50:12
// Design Name: 
// Module Name: SIM_spi_drive_TB
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


module SIM_spi_drive_TB();

localparam P_CLK_PERIOD = 20;
localparam P_DATA_WIDTH = 8 ;
localparam P_OP_INS     = 0 ,
           P_OP_READ    = 1 ,
           P_OP_WRITE   = 2 ;

reg clk,rst;

initial begin
    rst = 1;
    #120;
    @(posedge clk) rst = 0;
end

always begin
    clk = 0;
    #(P_CLK_PERIOD/2);
    clk = 1;
    #(P_CLK_PERIOD/2);
end

wire                    w_spi_cs         ;
wire                    w_spi_clk        ;
wire                    w_spi_mosi       ;
wire                    w_spi_miso       ;
wire                    WPn              ;
wire                    HOLDn            ;

pullup(w_spi_mosi);
pullup(w_spi_miso);
pullup(WPn       );
pullup(HOLDn     );

W25Q128JVxIM W25Q128JVxIM_u(   
    .CSn               (w_spi_cs         ),
    .CLK               (w_spi_clk        ),
    .DIO               (w_spi_mosi       ),
    .DO                (w_spi_miso       ),
    .WPn               (WPn              ),
    .HOLDn             (HOLDn            )
);

spi_top spi_top_u(
    .clk                (clk             ) ,
    .o_spi_cs           (w_spi_cs        ) ,
    .o_spi_clk          (w_spi_clk       ) ,
    .o_spi_mosi         (w_spi_mosi      ) ,
    .i_spi_miso         (w_spi_miso      )  
);

endmodule
