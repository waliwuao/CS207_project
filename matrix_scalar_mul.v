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
    input      [199:0] matrix_in,
    output reg [199:0] matrix_out,
    output reg         valid
);

    localparam MAX_DIM     = 5;
    localparam MAX_ELEM    = 25;
    localparam ELEM_WIDTH  = 8;

    integer i, j;
    integer idx;

    always @* begin
        matrix_out = {MAX_ELEM*ELEM_WIDTH{1'b0}};
        valid      = 1'b0;
        if (m == 0 || n == 0 || m > MAX_DIM || n > MAX_DIM) begin
            valid = 1'b0;
        end else begin
            for (i = 0; i < MAX_DIM; i = i + 1) begin
                for (j = 0; j < MAX_DIM; j = j + 1) begin
                    idx = (i*MAX_DIM + j)*ELEM_WIDTH;
                    if (i < m && j < n) begin
                        matrix_out[idx +: ELEM_WIDTH] = matrix_in[idx +: ELEM_WIDTH] * scalarValue;
                    end else begin
                        matrix_out[idx +: ELEM_WIDTH] = {ELEM_WIDTH{1'b0}};
                    end
                end
            end
            valid = 1'b1;
        end
    end

endmodule
