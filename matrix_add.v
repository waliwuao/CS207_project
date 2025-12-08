`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/12/08 18:09:19
// Design Name: 
// Module Name: matrix
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

module AddUnit (
    input             clk,
    input             reset,
    input      [2:0]  m,
    input      [2:0]  n,
    input      [199:0] matrixA,
    input      [199:0] matrixB,
    output reg [199:0] aPlusB,
    output reg         valid,
    output reg         addError
);

    integer i, j;
    integer idx;

    always @* begin
        aPlusB   = {200{1'b0}};
        valid    = 1'b0;
        addError = 1'b0;
        if (m == 0 || n == 0 || m > 5 || n > 5) begin
            addError = 1'b1;
        end else begin
            for (i = 0; i < 5; i = i + 1) begin
                for (j = 0; j < 5; j = j + 1) begin
                    idx = (i*5 + j)*8;
                    if (i < m && j < n) begin
                        aPlusB[idx +: 8] = matrixA[idx +: 8] + matrixB[idx +: 8];
                    end else begin
                        aPlusB[idx +: 8] = 8'd0;
                    end
                end
            end
            valid = 1'b1;
        end
    end

endmodule
