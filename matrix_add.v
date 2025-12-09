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
    input      [399:0] matrices_in,
    output reg [399:0] matrices_out,
    output reg         valid
);

    integer i, j;
    integer idx;
    reg [199:0] matrixA;
    reg [199:0] matrixB;

    always @* begin
        matrixA      = matrices_in[199:0];
        matrixB      = matrices_in[399:200];
        matrices_out = {400{1'b0}};
        valid    = 1'b0;
        if (m == 0 || n == 0 || m > 5 || n > 5) begin
            valid = 1'b0;
        end else begin
            for (i = 0; i < 5; i = i + 1) begin
                for (j = 0; j < 5; j = j + 1) begin
                    idx = (i*5 + j)*8;
                    if (i < m && j < n) begin
                        matrices_out[idx +: 8] = matrixA[idx +: 8] + matrixB[idx +: 8];
                    end else begin
                        matrices_out[idx +: 8] = 8'd0;
                    end
                end
            end
            valid = 1'b1;
        end
    end

endmodule
