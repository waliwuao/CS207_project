`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 
// Design Name: 
// Module Name: MatrixUartTx
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


module MatrixUartTx #(
    parameter NUM_DIGHT = 32
) (
    input  wire       clk,
    input             uartTxRstN,
    input             sendOne,
    input             promptStart,
    input  wire [1:0] promptSel,
    input  wire [199:0] matrixData,
    input  wire [7:0] m,
    input  wire [7:0] n,
    input  wire [7:0] id,
    input             ifID,
    input             ifNM,
    output wire       uartTx,
    output wire       busy
);
    reg sendOneD1, sendOneD2;
    reg promptD1, promptD2;
    always @(posedge clk or negedge uartTxRstN) begin
        if(!uartTxRstN) begin
            sendOneD1 <= 1'b0;
            sendOneD2 <= 1'b0;
            promptD1  <= 1'b0;
            promptD2  <= 1'b0;
        end else begin
            sendOneD1 <= sendOne;
            sendOneD2 <= sendOneD1;
            promptD1  <= promptStart;
            promptD2  <= promptD1;
        end
    end
    wire sendFlag;
    wire promptFlag;
    assign sendFlag   = sendOneD1 & ~sendOneD2;
    assign promptFlag = promptD1  & ~promptD2;

    localparam PROMPT_WAIT1   = 2'd0;
    localparam PROMPT_WAIT2   = 2'd1;
    localparam PROMPT_DISPLAY = 2'd2;

    function automatic [3:0] prompt_len;
        input [1:0] s;
        begin
            case (s)
                PROMPT_WAIT1:   prompt_len = 4'd6; // wait1\n
                PROMPT_WAIT2:   prompt_len = 4'd6; // wait2\n
                PROMPT_DISPLAY: prompt_len = 4'd8; // display\n
                default:        prompt_len = 4'd1;
            endcase
        end
    endfunction

    function automatic [7:0] prompt_char;
        input [1:0] s;
        input [3:0] idx;
        begin
            case (s)
                PROMPT_WAIT1: begin
                    case (idx)
                        0: prompt_char = "w"; 1: prompt_char = "a"; 2: prompt_char = "i";
                        3: prompt_char = "t"; 4: prompt_char = "1"; default: prompt_char = "\n";
                    endcase
                end
                PROMPT_WAIT2: begin
                    case (idx)
                        0: prompt_char = "w"; 1: prompt_char = "a"; 2: prompt_char = "i";
                        3: prompt_char = "t"; 4: prompt_char = "2"; default: prompt_char = "\n";
                    endcase
                end
                default: begin // display
                    case (idx)
                        0: prompt_char = "d"; 1: prompt_char = "i"; 2: prompt_char = "s";
                        3: prompt_char = "p"; 4: prompt_char = "l"; 5: prompt_char = "a";
                        6: prompt_char = "y"; default: prompt_char = "\n";
                    endcase
                end
            endcase
        end
    endfunction

    reg [2:0] ix,iy;//��������

    reg asciiStart;
    reg [7:0] key,txDt;
    wire [31:0] txData;
    reg [31:0] num;
    wire asciiDone,asciiBusy;
    BinaryToASCII asciiNum(
        .clk(clk),
        .rstN(uartTxRstN),
        .ifStart(asciiStart),
        .binaryNum(key),
        .asciiNum(txData),
        .ifDone(asciiDone),
        .ifBusy(asciiBusy)
    );
    reg txStart,isStart;
    wire txDataBusy;
    UartTx uartTxData(
        .clk(clk),
        .rstN(uartTxRstN),
        .txStart(txStart),
        .txData(txDt),
        .tx(uartTx),
        .txBusy(txDataBusy)
    );
    
    reg isID,isN,isM,isWait,isMatrix,txBusy;
    reg isPrompt;
    reg [3:0] promptIdx;
    reg [1:0] promptSelReg;
    reg[2:0] idx;


    task sendTx;
    inout   isDone;         // isID / isN / isM
    input   [7:0] keyVal;    // id/n/m
    input   isLineFeed; //�Ƿ��ͻ��з�
    begin
        if(!isWait) begin
            asciiStart <= 1'b1;
            key <= keyVal;
            isWait <= 1'b1;
            isStart <= 1'b0;
        end else if(!isStart && asciiBusy) begin
            asciiStart <= 1'b0;
        end else if(!isStart && asciiDone)begin
            isStart <= 1'b1;
            num <= txData;
            idx <= 3'b0;
            txStart <= 1'b0;
        end else if(isStart) begin
            if(txDataBusy && txStart) begin
                txStart <= 1'b0;
            end else if(!txDataBusy && !txStart) begin
                if(idx < 4) begin
                    case(idx)
                        0: txDt <= num[31:24];
                        1: txDt <= num[23:16];
                        2: txDt <= num[15:8];
                        3: txDt <= num[7:0];
                    endcase
                    txStart <= 1'b1;
                    idx <= idx + 1;
                end else if(idx == 4 && isLineFeed) begin
                    txDt <= 8'h0A;
                    txStart <= 1'b1;
                    idx <= idx + 1;
                end else begin
                    isDone = 1'b1;
                    isWait <= 1'b0;
                    isStart <= 1'b0;
                    asciiStart <= 1'b0;
                    txStart <= 1'b0;
                end
            end
        end
    end
    endtask


    always @(posedge clk or negedge uartTxRstN) begin
        if(!uartTxRstN) begin
            asciiStart <= 1'b0;
            txStart <= 1'b0;
            isStart <= 1'b0;
            ix <= 3'b0;
            iy <= 3'b0;
            isID <= 1'b0;
            isN <= 1'b0;
            isM <= 1'b0;
            isMatrix <= 1'b0;
            isWait <= 1'b0;
            idx <= 3'b0;
            txBusy <= 1'b0;
            isPrompt <= 1'b0;
            promptIdx <= 4'd0;
            promptSelReg <= PROMPT_WAIT1;
        end else if(promptFlag && !txBusy) begin
            // Prompt send takes priority when idle
            asciiStart <= 1'b0;
            txStart <= 1'b0;
            isStart <= 1'b0;
            ix <= 3'b0;
            iy <= 3'b0;
            isID <= 1'b0;
            isN <= 1'b0;
            isM <= 1'b0;
            isMatrix <= 1'b0;
            isWait <= 1'b0;
            idx <= 3'b0;
            isPrompt <= 1'b1;
            promptIdx <= 4'd0;
            promptSelReg <= promptSel;
            txBusy <= 1'b1;
        end else if(sendFlag && !txBusy) begin
            asciiStart <= 1'b0;
            txStart <= 1'b0;
            isStart <= 1'b0;
            ix <= 3'b0;
            iy <= 3'b0;
            isID <= 1'b0;
            isN <= 1'b0;
            isM <= 1'b0;
            isMatrix <= 1'b0;
            isWait <= 1'b0;
            idx <= 3'b0;
            isPrompt <= 1'b0;
            txBusy <= 1'b1;
        end else if(txBusy) begin
            if (isPrompt) begin
                if(txDataBusy && txStart) begin
                    txStart <= 1'b0;
                end else if(!txDataBusy && !txStart) begin
                    txDt <= prompt_char(promptSelReg, promptIdx);
                    txStart <= 1'b1;
                    if (promptIdx + 1'b1 < prompt_len(promptSelReg)) begin
                        promptIdx <= promptIdx + 1'b1;
                    end else begin
                        isPrompt <= 1'b0;
                        txBusy <= 1'b0;
                    end
                end
            end else begin
                if(!isID && ifID) begin
                    sendTx(isID, id, 1'b1);
                end else if(!isM && ifNM) begin
                    sendTx(isM, m, 1'b0);
                end else if(!isN && ifNM) begin
                    sendTx(isN, n, 1'b1);
                end else if(iy<m) begin
                    if(isMatrix) begin
                        if(ix<n-1) begin
                            ix <= ix + 1;
                        end else begin
                            ix <= 0;
                            iy <= iy + 1;
                        end
                        isMatrix <= 1'b0;
                    end else begin
                        if(ix<n-1) begin
                            sendTx(isMatrix, (matrixData>>((iy*n+ix)*8))&8'hFF , 1'b0);
                        end else begin
                            sendTx(isMatrix, (matrixData>>((iy*n+ix)*8))&8'hFF, 1'b1);
                        end
                    end
                end else begin
                    txBusy <= 1'b0;
                end
            end
        end
    end

    // Expose internal busy so caller can sequence transmissions safely.
    assign busy = txBusy;
endmodule
