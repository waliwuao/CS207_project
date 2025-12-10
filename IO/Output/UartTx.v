`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 
// Design Name: 
// Module Name: UartTx
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


module UartTx #(
    parameter CLK_FREQ = 100000000,
    parameter BAUD_RATE = 115200
)(
    input wire clk,
    input wire rstN,
    input wire txStart,         // 触发
    input wire [7:0] txData,    // 要发送的字节
    output reg tx,               // 串口输出
    output reg txBusy           // 
);

    localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;

    reg [15:0] baudCnt;
    reg [3:0] bitIdx;
    reg [9:0] txShift;

    always @(posedge clk or negedge rstN) begin
        if(!rstN) begin
            baudCnt <= 0;
            bitIdx <= 0;
            txShift <= 10'b1111111111;
            tx <= 1'b1;
            txBusy <= 1'b0;
        end else begin
            if(txStart && !txBusy) begin
                // 格式：起始位(0) + 数据(LSB first) + 停止�????(1)
                txShift <= {1'b1, txData, 1'b0};
                txBusy <= 1'b1;
                baudCnt <= 0;
                bitIdx <= 0;
            end else if(txBusy) begin
                if(baudCnt < BAUD_DIV - 1) begin
                    baudCnt <= baudCnt + 1;
                end else begin
                    baudCnt <= 0;
                    tx <= txShift[0];
                    txShift <= {1'b1, txShift[9:1]};  // 右移1�????
                    bitIdx <= bitIdx + 1;
                    if(bitIdx == 9) begin
                        txBusy <= 1'b0;
                    end
                end
            end
        end
    end
endmodule
