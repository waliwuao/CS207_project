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
    input      [199:0] matrixA_in,
    input      [199:0] matrixB_in,
    output reg [2:0]  c_m,
    output reg [2:0]  c_n,
    output reg [199:0] matrix_out,
    output reg         valid
);

    localparam MAX_DIM     = 5;
    localparam MAX_ELEM    = 25;
    localparam ELEM_WIDTH  = 8;

    integer i, j, k;
    integer idx_a;
    integer idx_b;
    integer idx_c;
    reg [15:0] acc;

    always @* begin
        matrix_out = {MAX_ELEM*ELEM_WIDTH{1'b0}};
        c_m        = 3'd0;
        c_n        = 3'd0;
        valid      = 1'b0;
        if (a_m == 0 || a_n == 0 || b_m == 0 || b_n == 0 ||
            a_m > MAX_DIM || a_n > MAX_DIM || b_m > MAX_DIM || b_n > MAX_DIM ||
            a_n != b_m) begin
            valid = 1'b0;
        end else begin
            c_m = a_m;
            c_n = b_n;
            for (i = 0; i < MAX_DIM; i = i + 1) begin
                for (j = 0; j < MAX_DIM; j = j + 1) begin
                    acc = 16'd0;
                    if (i < a_m && j < b_n) begin
                        for (k = 0; k < MAX_DIM; k = k + 1) begin
                            if (k < a_n) begin
                                idx_a = (i*MAX_DIM + k)*ELEM_WIDTH;
                                idx_b = (k*MAX_DIM + j)*ELEM_WIDTH;
                                acc = acc + matrixA_in[idx_a +: ELEM_WIDTH] * matrixB_in[idx_b +: ELEM_WIDTH];
                            end
                        end
                        idx_c = (i*MAX_DIM + j)*ELEM_WIDTH;
                        matrix_out[idx_c +: ELEM_WIDTH] = acc[ELEM_WIDTH-1:0];
                    end
                end
            end
            valid = 1'b1;
        end
    end

endmodule

