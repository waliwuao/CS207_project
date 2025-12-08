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

module MatrixMultiplyUnit (
    input             clk,
    input             reset,
    input      [2:0]  a_m,
    input      [2:0]  a_n,
    input      [2:0]  b_m,
    input      [2:0]  b_n,
    input      [199:0] matrixA,
    input      [199:0] matrixB,
    output reg [2:0]  c_m,
    output reg [2:0]  c_n,
    output reg [399:0] aMulB,
    output reg         valid,
    output reg         mulError
);

    integer i, j, k;
    integer idx_a;
    integer idx_b;
    integer idx_c;
    reg [15:0] acc;

    always @* begin
        aMulB    = {400{1'b0}};
        c_m      = 3'd0;
        c_n      = 3'd0;
        valid    = 1'b0;
        mulError = 1'b0;
        if (a_m == 0 || a_n == 0 || b_m == 0 || b_n == 0 ||
            a_m > 5 || a_n > 5 || b_m > 5 || b_n > 5 ||
            a_n != b_m) begin
            mulError = 1'b1;
        end else begin
            c_m = a_m;
            c_n = b_n;
            for (i = 0; i < 5; i = i + 1) begin
                for (j = 0; j < 5; j = j + 1) begin
                    acc = 16'd0;
                    if (i < a_m && j < b_n) begin
                        for (k = 0; k < 5; k = k + 1) begin
                            if (k < a_n) begin
                                idx_a = (i*5 + k)*8;
                                idx_b = (k*5 + j)*8;
                                acc = acc + matrixA[idx_a +: 8] * matrixB[idx_b +: 8];
                            end
                        end
                        idx_c = (i*5 + j)*16;
                        aMulB[idx_c +: 16] = acc;
                    end
                end
            end
            valid = 1'b1;
        end
    end

endmodule

