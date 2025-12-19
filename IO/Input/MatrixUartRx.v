`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: xch
// 
// Create Date: 
// Design Name: 
// Module Name: MartixUartRx
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


module MatrixUartRx (// put \n as end
    //element need in [0,9]
    input wire clk,
    input wire uartRxRstN,
    input wire rx, 
    input wire rxStart,
    input wire [7:0] lowerLimit,
    input wire [7:0] upperLimit,
    output reg [7:0] m,
    output reg [7:0] n,
    output reg [199:0] matrixData,
    output reg rxDone,
    output reg rxError
);

    // reg sendOneD1, sendOneD2;
    // always @(posedge clk or negedge rstN) begin
    //     if(!uartTxRstN) begin
    //         sendOneD1 <= 1'b0;
    //         sendOneD2 <= 1'b0;
    //     end else begin
    //         sendOneD1 <= sendOne;
    //         sendOneD2 <= sendOneD1;
    //     end
    // end
    // wire rxStart;
    // assign rxStart = sendOneD1 & ~sendOneD2;

    wire rxDoneWire;
    wire [7:0] rxData;
    reg [7:0] tmp;
    UartRx #(
        .CLK_FREQ(100_000_000),
        .BAUD_RATE(115200)
    ) uart_rx_inst (
        .clk(clk),
        .rstN(uartRxRstN),
        .rx(rx),
        .rxData(rxData),
        .rxDone(rxDoneWire)
    );

    reg isM,isN;
    reg isBusy;
    reg isNum;
    reg [7:0] idx;

    function [0:0] checkNum;
    input [7:0] a;
    begin
        checkNum = (a>=8'd48 && a<=8'd57) ? 1'b1 : 1'b0;
    end
    endfunction
    function [0:0] checkBlank;
    input [7:0] a;
    begin
        checkBlank = (a==8'h20) ? 1'b1 : 1'b0;
    end
    endfunction
    function [0:0] checkLineFeed;
    input [7:0] a;
    begin
        checkLineFeed = (a==8'h0A||a==8'h0D) ? 1'b1 : 1'b0;
    end
    endfunction

    task getNum;
    inout [7:0] num;
    inout isDone;
    input [7:0] lower;
    input [7:0] upper;
    begin
        if(checkNum(rxData)) begin
            if({2'b0,num}*10+(rxData-8'd48) <= upper) begin
                num = num*10+(rxData-8'd48);
            end else begin
                rxError <= 1'b1;
                isBusy <= 1'b0;
            end
        end else if(checkBlank(rxData)) begin
            if(num >= lower && num <= upper) begin
                isDone = 1'b1;
            end else begin
                rxError <= 1'b1;
                isBusy <= 1'b0;
            end
        end else if(checkLineFeed(rxData)) begin
            if(num >= lower && num <= upper) begin
                if(isM && isN) begin
                    rxError <= 1'b0;
                    isM <= 1'b0;
                    isN <= 1'b0;
                    matrixData <= matrixData + ({200'b0,num}<<(idx*8));
                    num = 8'b0;
                end else begin
                    rxError <= 1'b1;
                end
            end else begin
                rxError <= 1'b1;
            end
            rxDone <= 1'b1;
            isBusy <= 1'b0;
        end else begin
            rxError <= 1'b1;
            isBusy <= 1'b0;
        end
    end
    endtask

    always @(posedge clk or negedge uartRxRstN) begin
        if (!uartRxRstN) begin
            m <= 8'b0;
            n <= 8'b0;
            matrixData <= 200'b0;
            rxDone <= 1'b0;
            rxError <= 1'b0;
            isBusy <= 1'b0;
            isM <= 1'b0;
            isN <= 1'b0;
            isNum <= 1'b0;
            idx <= 8'b0;
            tmp <= 8'b0;
        end else begin
            rxDone <= 1'b0;
            if (rxStart && !isBusy) begin
                isBusy <= 1'b1;
                isNum <= 1'b0;
                isM <= 1'b0;
                isN <= 1'b0;
                isNum <= 1'b0;
                idx <= 8'b0;
                matrixData <= 200'b0;
                m <= 8'b0;
                n <= 8'b0;
                tmp <= 8'b0;
                rxError <= 1'b0;
            end else if(!isBusy && rxError) begin
                if(rxDoneWire && checkLineFeed(rxData)) begin
                    rxDone <= 1'b1;
                    isBusy <= 1'b0;
                    isM <= 1'b0;
                    isN <= 1'b0;
                end
            end else if(!isBusy && isM && isN && idx == n*m) begin
                if(rxDoneWire && checkLineFeed(rxData)) begin
                    rxDone <= 1'b1;
                    rxError <= 1'b0;
                    isBusy <= 1'b0;
                    isM <= 1'b0;
                    isN <= 1'b0;
                end
            end else if(isBusy && rxDoneWire) begin
                if(!isM) begin
                    getNum(m,isM,8'd1,8'd5);
                end else if(!isN) begin
                    getNum(n,isN,8'd1,8'd5);
                end else if(idx < m*n) begin
                    getNum(tmp,isNum,lowerLimit,upperLimit);
                    if(isNum) begin
                        if(idx==n*m-1) begin
                            isBusy <= 1'b0;
                            rxError <= 1'b0;
                        end
                        matrixData <= (matrixData&(({1'b1}<<(idx*8))-1)) + ({200'b0,tmp}<<(idx*8));
                        tmp <= 8'b0;
                        idx <= idx + 1;
                        isNum <= 1'b0;
                    end
                end
            end
        end
    end
endmodule
