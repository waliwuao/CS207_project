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

module ScalarMultiplyUnit (
    input             clk,
    input             reset,
    input      [2:0]  m,
    input      [2:0]  n,
    input      [3:0]  scalarValue,
    input      [199:0] matrixA,
    output reg [199:0] scalarMul,
    output reg         valid
);

    integer i, j;
    integer idx;

    always @* begin
        scalarMul = {200{1'b0}};
        valid     = 1'b0;
        if (m == 0 || n == 0 || m > 5 || n > 5) begin
            valid = 1'b0;
        end else begin
            for (i = 0; i < 5; i = i + 1) begin
                for (j = 0; j < 5; j = j + 1) begin
                    idx = (i*5 + j)*8;
                    if (i < m && j < n) begin
                        scalarMul[idx+7:idx] = matrixA[idx+7:idx] * scalarValue;
                    end else begin
                        scalarMul[idx+7:idx] = 8'd0;
                    end
                end
            end
            valid = 1'b1;
        end
    end

endmodule
