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

module ConvolutionUnit (
    input             clk,
    input             reset,
    input      [2:0]  in_m,
    input      [2:0]  in_n,
    input      [1:0]  k_m,
    input      [1:0]  k_n,
    input      [199:0] matrix_in,
    input      [71:0]  kernelMatrix,
    output reg [2:0]  out_m,
    output reg [2:0]  out_n,
    output reg [199:0] matrix_out,
    output reg         valid,
    output reg [9:0]   cycleCount
);

    localparam MAX_DIM     = 5;
    localparam MAX_ELEM    = 25;
    localparam ELEM_WIDTH  = 8;

    integer i, j, ki, kj;
    integer idx_in;
    integer idx_k;
    integer idx_out;
    reg [15:0] acc;

    always @* begin
        matrix_out = {MAX_ELEM*ELEM_WIDTH{1'b0}};
        out_m      = 3'd0;
        out_n      = 3'd0;
        valid      = 1'b0;
        cycleCount = 10'd0;
        if (in_m == 0 || in_n == 0 || k_m == 0 || k_n == 0 ||
            in_m > MAX_DIM || in_n > MAX_DIM || k_m > 3 || k_n > 3 ||
            in_m < k_m || in_n < k_n) begin
            valid = 1'b0;
        end else begin
            out_m = in_m - k_m + 1;
            out_n = in_n - k_n + 1;
            for (i = 0; i < MAX_DIM; i = i + 1) begin
                for (j = 0; j < MAX_DIM; j = j + 1) begin
                    if (i < out_m && j < out_n) begin
                        acc = 16'd0;
                        for (ki = 0; ki < 3; ki = ki + 1) begin
                            for (kj = 0; kj < 3; kj = kj + 1) begin
                                if (ki < k_m && kj < k_n) begin
                                    idx_in = ((i + ki)*MAX_DIM + (j + kj))*ELEM_WIDTH;
                                    idx_k  = (ki*3 + kj)*ELEM_WIDTH;
                                    acc = acc + matrix_in[idx_in +: ELEM_WIDTH] * kernelMatrix[idx_k +: ELEM_WIDTH];
                                end
                            end
                        end
                        idx_out = (i*MAX_DIM + j)*ELEM_WIDTH;
                        matrix_out[idx_out +: ELEM_WIDTH] = acc[ELEM_WIDTH-1:0];
                    end
                end
            end
            valid = 1'b1;
        end
    end

endmodule

