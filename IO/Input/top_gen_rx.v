`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 
// Design Name: 
// Module Name: top_gen_rx
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


module top_gen_rx (
    input wire clk,
    input wire uartRxRstN,
    input wire uartTxRstN,
    input wire rx, 
    input wire rxStart,
    output wire rxError,
    output wire uart_tx,   
    output wire uart_tx_work
    // output wire rxDone
);
    wire rxDone;
    reg send_one;
    wire [7:0] m,n,cnt;
    reg [7:0] M,N,CNT;
    GenerationUartRx generation_uart_rx_inst (
        .clk(clk),
        .uartRxRstN(uartRxRstN),
        .rx(rx),
        .rxStart(rxStart),
        .m(m),
        .n(n),
        .cnt(cnt),
        .rxDone(rxDone),
        .rxError(rxError)
    );

    MatrixUartTx matrix_uart_tx_inst (
        .clk(clk),
        .uartTxRstN(uartTxRstN),
        .sendOne(send_one),
        .matrixData({200'b0}),
        .m(M),
        .n(N),
        .id(CNT),
        .ifID(1'b1),
        .ifNM(1'b1),
        .uartTx(uart_tx)
    );

    assign uart_tx_work = send_one;

    always @(posedge clk or negedge uartTxRstN) begin
        if (!uartTxRstN) begin
            send_one <= 1'b0;
            M <= 8'b0;
            N <= 8'b0;
        end else begin
            if (rxDone && !rxError) begin
                send_one <= 1'b1;
                M <= m;
                N <= n;
                CNT <= cnt;
            end else begin
                send_one <= 1'b0;
            end
        end
    end

endmodule
