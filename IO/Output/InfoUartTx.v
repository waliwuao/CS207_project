`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 
// Design Name: 
// Module Name: InfoUartTx
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


module InfoUartTx #(
    parameter NUM_DIGHT = 32
) ( 
    input wire clk, 
    input uartTxRstN,
    input sendOne,
    input [74:0] matrixListInfo, // for m,n matrix, [((m-1)*5+n)*3-1:((m-1)*5+n-1)*3] means count of this kind of matrix.
    output wire uartTx
);
    reg sendOneD1, sendOneD2;
    always @(posedge clk or negedge uartTxRstN) begin
        if(!uartTxRstN) begin
            sendOneD1 <= 1'b0;
            sendOneD2 <= 1'b0;
        end else begin
            sendOneD1 <= sendOne;
            sendOneD2 <= sendOneD1;
        end
    end
    wire sendFlag;
    assign sendFlag = sendOneD1 & ~sendOneD2;

    reg [7:0] idx,count;
    reg asciiStart;
    reg [7:0] key;
    wire [23:0] txData;
    reg [23:0] num;
    wire asciiDone,asciiBusy;

    BinaryToOneASCII asciiNum(
        .clk(clk),
        .rstN(uartTxRstN),
        .ifStart(asciiStart),
        .binaryNum(key),
        .asciiNum(txData),
        .ifDone(asciiDone),
        .ifBusy(asciiBusy)
    );

    reg isStart,txStart;
    wire txDataBusy;
    reg [7:0] txDt;
    UartTx uartTxData(
        .clk(clk),
        .rstN(uartTxRstN),
        .txStart(txStart),
        .txData(txDt),
        .tx(uartTx),
        .txBusy(txDataBusy)
    );

    reg isWait,isCountDone,isInfo,txBusy;
    reg [2:0] idy,ix,iy;
    always @(posedge clk or negedge uartTxRstN) begin
        if(!uartTxRstN) begin
            isCountDone <= 1'b0;
            idx <= 8'b0;
            count <= 8'b0;
            ix <= 3'b0;
            iy <= 3'b0;
            isInfo <= 1'b0;
            isWait <= 1'b0;
            isStart <= 1'b0;
            txStart <= 1'b0;
            idy <= 3'b0;
            asciiStart <= 1'b0;
            txBusy <= 1'b0;
        end else if(sendFlag && !txBusy) begin
            isCountDone <= 1'b0;
            idx <= 8'b0;
            count <= 8'b0;
            ix <= 3'b0;
            iy <= 3'b0;
            isInfo <= 1'b0;
            isWait <= 1'b0;
            isStart <= 1'b0;
            txStart <= 1'b0;
            idy <= 3'b0;
            asciiStart <= 1'b0;
            txBusy <= 1'b1;
        end else if(txBusy) begin
            if(!isCountDone) begin
                if(idx >= 25) begin
                    if(!isWait) begin
                        asciiStart <= 1'b1;
                        key <= count;
                        isWait <= 1'b1;
                        isStart <= 1'b0;
                    end else if(!isStart && asciiBusy) begin
                        asciiStart <= 1'b0;
                    end else if(!isStart && asciiDone)begin
                        isStart <= 1'b1;
                        num <= txData;
                        idy <= 3'b0;
                        txStart <= 1'b0;
                    end else if(isStart) begin
                        if(txDataBusy && txStart) begin
                            txStart <= 1'b0;
                        end else if(!txDataBusy && !txStart) begin
                            if(idy < 4) begin
                                if (idy==1 && num[23:16]==8'h20 && num[15:8]==8'h20) begin
                                    idy <= idy + 1;
                                end else if (idy==0 && num[23:16]==8'h20) begin
                                    idy <= idy + 1;
                                end else begin
                                    case(idy)
                                        0: txDt <= num[23:16];
                                        1: txDt <= num[15:8];
                                        2: txDt <= num[7:0];
                                        3: txDt <= 8'h20;
                                    endcase
                                    txStart <= 1'b1;
                                    idy <= idy + 1;
                                end
                            end else begin
                                isCountDone <= 1'b1;
                                isWait <= 1'b0;
                                isStart <= 1'b0;
                                asciiStart <= 1'b0;
                                txStart <= 1'b0;
                                idx <= 8'b0;
                                idy <= 3'b0;
                            end
                        end
                    end
                end else begin
                    count <= count + ((matrixListInfo>>(idx*3))&3'b111);
                    idx <= idx + 1;
                end
            end else if(iy<5) begin
                if(isInfo) begin
                    if(ix<4) begin
                        ix <= ix + 1;
                    end else begin
                        ix <= 0;
                        iy <= iy + 1;
                    end
                    isInfo <= 1'b0;
                end else if(((matrixListInfo>>((iy*5+ix)*3))&3'b111) == 0) begin
                    isInfo <= 1'b1;
                end else begin
                    if(!isStart) begin
                        isStart <= 1'b1;
                        idy <= 3'b0;
                        txStart <= 1'b0;
                    end else if(isStart) begin
                        if(txDataBusy && txStart) begin
                            txStart <= 1'b0;
                        end else if(!txDataBusy && !txStart) begin
                            if(idy < 6) begin
                                case(idy)
                                    0: txDt <= iy+8'h31;
                                    1: txDt <= 8'h2A;
                                    2: txDt <= ix+8'h31;
                                    3: txDt <= 8'h2A;
                                    4: txDt <= ((matrixListInfo>>((iy*5+ix)*3))&3'b111)+8'h30;
                                    5: txDt <= 8'h20;
                                endcase
                                txStart <= 1'b1;
                                idy <= idy + 1;
                            end else begin
                                isInfo <= 1'b1;
                                isStart <= 1'b0;
                                txStart <= 1'b0;
                                idy <= 3'b0;
                            end
                        end
                    end
                end
            end else begin
                txBusy <= 1'b0;
            end
        end
    end
endmodule
