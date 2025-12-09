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
    input      [399:0] matrices_in,
    output reg [2:0]  c_m,
    output reg [2:0]  c_n,
    output reg [399:0] matrices_out,
    output reg         valid
);

    integer i, j, k;
    integer idx_a;
    integer idx_b;
    integer idx_c;
    reg [15:0] acc;
    reg [199:0] matrixA;
    reg [199:0] matrixB;

    always @* begin
        matrixA      = matrices_in[199:0];
        matrixB      = matrices_in[399:200];
        matrices_out = {400{1'b0}};
        c_m      = 3'd0;
        c_n      = 3'd0;
        valid    = 1'b0;
        if (a_m == 0 || a_n == 0 || b_m == 0 || b_n == 0 ||
            a_m > 5 || a_n > 5 || b_m > 5 || b_n > 5 ||
            a_n != b_m) begin
            valid = 1'b0;
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
                                acc = acc + matrixA[idx_a+7:idx_a] * matrixB[idx_b+7:idx_b];
                            end
                        end
                        idx_c = (i*5 + j)*8;
                        matrices_out[idx_c +: 8] = acc[7:0];
                    end
                end
            end
            valid = 1'b1;
        end
    end

endmodule

