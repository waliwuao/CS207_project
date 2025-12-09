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


module TransposeUnit (
    input             clk,
    input             reset,
    input      [2:0]  m_in,
    input      [2:0]  n_in,
    input      [199:0] matrix_in,
    output reg [2:0]  m_out,
    output reg [2:0]  n_out,
    output reg [199:0] matrix_out,
    output reg         valid
);

    localparam MAX_DIM     = 5;
    localparam MAX_ELEM    = 25;
    localparam ELEM_WIDTH  = 8;

    integer i, j;
    integer idx_in;
    integer idx_out;

    always @* begin
        matrix_out = {MAX_ELEM*ELEM_WIDTH{1'b0}};
        m_out      = 3'd0;
        n_out      = 3'd0;
        valid      = 1'b0;
        if (m_in == 0 || n_in == 0 || m_in > MAX_DIM || n_in > MAX_DIM) begin
            valid = 1'b0;
        end else begin
            m_out = n_in;
            n_out = m_in;
            for (i = 0; i < MAX_DIM; i = i + 1) begin
                for (j = 0; j < MAX_DIM; j = j + 1) begin
                    idx_in  = (i*MAX_DIM + j)*ELEM_WIDTH;
                    idx_out = (j*MAX_DIM + i)*ELEM_WIDTH;
                    if (i < m_in && j < n_in) begin
                        matrix_out[idx_out +: ELEM_WIDTH] = matrix_in[idx_in +: ELEM_WIDTH];
                    end else begin
                        matrix_out[idx_out +: ELEM_WIDTH] = {ELEM_WIDTH{1'b0}};
                    end
                end
            end
            valid = 1'b1;
        end
    end

endmodule
