`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: xch
// 
// Create Date: 
// Design Name: 
// Module Name: GenerationUartRx
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


module GenerationUartRx (// put \n as end
    input wire clk,
    input wire uartRxRstN,
    input wire rx, 
    input wire rxStart,
    output reg [7:0] m,
    output reg [7:0] n,
    output reg [7:0] cnt,
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
    reg isCnt;

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
                    isDone = 1'b1;
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
            cnt <= 8'b0;
            rxDone <= 1'b0;
            rxError <= 1'b0;
            isBusy <= 1'b0;
            isM <= 1'b0;
            isN <= 1'b0;
            isCnt <= 1'b0;
        end else begin
            rxDone <= 1'b0;
            if (rxStart && !isBusy) begin
                isBusy <= 1'b1;
                isM <= 1'b0;
                isN <= 1'b0;
                isCnt <= 1'b0;
                m <= 8'b0;
                n <= 8'b0;
                cnt <= 8'b0;
                rxError <= 1'b0;
            end else if(!isBusy && rxError) begin
                if(rxDoneWire && checkLineFeed(rxData)) begin
                    rxDone <= 1'b1;
                    isBusy <= 1'b0;
                    isM <= 1'b0;
                    isN <= 1'b0;
                end
            end else if(isBusy && rxDoneWire) begin
                if(!isM) begin
                    getNum(m,isM,8'd1,8'd5);
                end else if(!isN) begin
                    getNum(n,isN,8'd1,8'd5);
                end else if(!isCnt) begin
                    getNum(cnt,isCnt,8'd0,8'd2);
                    if(isCnt) begin
                        isBusy <= 1'b0;
                        rxError <= 1'b0;
                        isCnt <= 1'b0;
                        if(!checkLineFeed(rxData)) begin
                            rxError <= 1'b1;
                        end
                    end
                end
            end
        end
    end
endmodule
