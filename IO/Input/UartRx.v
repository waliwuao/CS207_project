`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: xch
// 
// Create Date: 
// Design Name: 
// Module Name: UartRx
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 输入单个数据
// Dependencies: 
// 
// Revision:
// Revision 0.01
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module UartRx #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 115200
)(
    input wire clk,
    input wire rstN,
    input wire rx,             // 串口输入信号
    output reg [7:0] rxData,  // 接收到的字节数据
    output reg rxDone         // 数据接收完成标志
);

    localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;

    reg [15:0] baudCnt;
    reg [3:0] bitIdx;
    reg [9:0] rxShift;
    reg rxBusy;
    reg rxD1, rxD2;

    // 同步处理防止亚稳态
    always @(posedge clk) begin
        rxD1 <= rx;
        rxD2 <= rxD1;
    end

    // UART接收状态机
    always @(posedge clk or negedge rstN) begin
        if (!rstN) begin
            baudCnt <= 0;
            bitIdx <= 0;
            rxBusy <= 0;
            rxDone <= 0;
            rxData <= 8'b0;
        end else begin
            rxDone <= 0;
            if (!rxBusy) begin
                if (rxD2 == 0) begin  // 检测到起始位
                    rxBusy <= 1;
                    baudCnt <= BAUD_DIV / 2; // 对齐到数据中间
                    bitIdx <= 0;
                end
            end else begin
                if (baudCnt == BAUD_DIV - 1) begin
                    baudCnt <= 0;
                    bitIdx <= bitIdx + 1;
                    case (bitIdx)
                        0: ; // 起始位
                        1,2,3,4,5,6,7,8: rxShift[bitIdx-1] <= rxD2;
                        9: begin
                            rxBusy <= 0;
                            rxData <= rxShift[7:0];
                            rxDone <= 1;
                        end
                    endcase
                end else begin
                    baudCnt <= baudCnt + 1;
                end
            end
        end
    end
endmodule
