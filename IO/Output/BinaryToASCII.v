`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 
// Design Name: 
// Module Name: BinaryToASCII
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


module BinaryToASCII (
    input clk,
    input rstN,
    input ifStart,
    input [7:0] binaryNum,
    output reg [31:0] asciiNum,
    output reg ifDone,
    output reg ifBusy
);
    reg [11:0] bcdNum;
    reg [2:0] idx;
    reg [1:0] pos;
    always @(posedge clk or negedge rstN) begin
        if(!rstN) begin
            ifDone <= 1'b0;
            ifBusy <= 1'b0;
        end else if(ifStart && !ifBusy) begin
            ifBusy <= 1'b1;
            bcdNum <= {4'b0, binaryNum};
            idx <= 3'b0;
            pos <= 2'b0;
            ifDone <= 1'b0;
            ifBusy <= 1'b1;
        end else if(ifBusy) begin
            if(idx >= 7) begin
                if(bcdNum[11:4] == 0) begin
                    asciiNum <= {bcdNum[3:0]+8'h30, 8'h20, 8'h20, 8'h20};
                end else if(bcdNum[11:8] == 0) begin
                    asciiNum <= {bcdNum[7:4]+8'h30, bcdNum[3:0]+8'h30, 8'h20, 8'h20};
                end else begin
                    asciiNum <= {bcdNum[11:8]+8'h30, bcdNum[7:4]+8'h30, bcdNum[3:0]+8'h30, 8'h20};
                end
                ifBusy <= 1'b0;
                ifDone <= 1'b1;
            end else if(pos > 2) begin
                idx <= idx + 1;
                pos <= 0;
                ifDone <= 1'b0;
            end else begin
                ifDone <= 1'b0;
                if(8+pos*4-(idx+1)<=11 && ((bcdNum>>(8+pos*4-(idx+1)))&4'b1111) >= 5) begin
                    bcdNum <= bcdNum + (3<<(8+pos*4-(idx+1)));
                end
                pos <= pos + 1;
            end
            //16-(idx+1)
            //12-(idx+1)
            //8-(idx+1)
        end else begin
            ifDone <= 1'b0;
        end
    end
endmodule
