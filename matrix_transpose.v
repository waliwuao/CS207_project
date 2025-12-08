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
    input      [199:0] matrixA,
    output reg [2:0]  m_out,
    output reg [2:0]  n_out,
    output reg [199:0] matrixAT,
    output reg         valid
);

    integer i, j;
    integer idx_in;
    integer idx_out;

    always @* begin
        matrixAT = {200{1'b0}};
        m_out    = 3'd0;
        n_out    = 3'd0;
        valid    = 1'b0;
        if (m_in == 0 || n_in == 0 || m_in > 5 || n_in > 5) begin
            valid = 1'b0;
        end else begin
            m_out = n_in;
            n_out = m_in;
            for (i = 0; i < 5; i = i + 1) begin
                for (j = 0; j < 5; j = j + 1) begin
                    idx_in  = (i*5 + j)*8;
                    idx_out = (j*5 + i)*8;
                    if (i < m_in && j < n_in) begin
                        matrixAT[idx_out+7:idx_out] = matrixA[idx_in+7:idx_in];
                    end else begin
                        matrixAT[idx_out+7:idx_out] = 8'd0;
                    end
                end
            end
            valid = 1'b1;
        end
    end

endmodule
