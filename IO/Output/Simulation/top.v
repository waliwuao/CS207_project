`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 
// Design Name: 
// Module Name: top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module top (
    input  wire clk,
    input  wire uart_tx_rst_n,
    input  wire send_one,  // �??测上升沿：有�??个上升沿就发送一次数�??
    output wire uart_tx,   // 串口输出（连接到板子�?? TX 引脚�??
    output wire uart_tx_work // 可用于指示发送工作状态（本例用常量）
);
    //�?要哪个开那个

    //矩阵信息输出
    wire [74:0] matrixListInfo = {25{3'd5}};
    InfoUartTx info(
        .clk(clk),
        .uartTxRstN(uart_tx_rst_n),
        .sendOne(send_one),
        .matrixListInfo(matrixListInfo),
        .uartTx(uart_tx)
    );

    /*
    //矩阵输出
    wire [199:0] matrixData = {25{8'd9}};
    wire [7:0] m = 8'd5;
    wire [7:0] n = 8'd5;
    wire [7:0] id = 8'd1;
    wire ifID = 1'b1;
    wire ifNM = 1'b1;
    MatrixUartTx matrix(
        .clk(clk),
        .uartTxRstN(uart_tx_rst_n),
        .sendOne(send_one),
        .matrixData(matrixData),
        .m(m),
        .n(n),
        .id(id),
        .ifID(ifID),
        .ifNM(ifNM),
        .uartTx(uart_tx)
    );
    */


    assign uart_tx_work = uart_tx_rst_n;

endmodule
