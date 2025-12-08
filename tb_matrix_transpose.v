`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/12/08 21:09:36
// Design Name: 
// Module Name: matrix_sim
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


module tb_matrix_transpose;
    reg  clk;
    reg  reset;
    reg  [2:0] m_in;
    reg  [2:0] n_in;
    reg  [199:0] matrixA;
    wire [2:0] m_out;
    wire [2:0] n_out;
    wire [199:0] matrixAT;
    wire valid;

    TransposeUnit dut (
        .clk(clk), .reset(reset), .m_in(m_in), .n_in(n_in), .matrixA(matrixA), .m_out(m_out), .n_out(n_out), .matrixAT(matrixAT), .valid(valid)
    );

    // 仿照 tb_matrix_add：inout 便于逐项写入
    task automatic set_elem(inout reg [199:0] mat, input integer r, input integer c, input [7:0] val);
        integer idx;
        begin
            idx = (r*5 + c)*8;
            mat[idx +: 8] = val;
        end
    endtask

    integer i, j, idx;

    initial begin
        clk = 1'b0;
        reset = 1'b0;
        m_in = 3'd1;
        n_in = 3'd3;

        // 清零矩阵
        matrixA = {200{1'b0}};

        set_elem(matrixA, 0, 0, 8'd1);
        set_elem(matrixA, 0, 1, 8'd2);
        set_elem(matrixA, 0, 2, 8'd3);

        #10;

        $display("---------------------------------------");
        $display("Transpose Result:");
        $display("Input dims: %0d x %0d", m_in, n_in);
        $display("Status: valid=%0d", valid);
        $display("Output dims: %0d x %0d", m_out, n_out);
        $display("---------------------------------------");

        if (valid) begin
            for (i = 0; i < m_out; i = i + 1) begin
                for (j = 0; j < n_out; j = j + 1) begin
                    idx = (i*5 + j)*8;
                    $write("%4d ", matrixAT[idx +: 8]);
                end
                $display("");
            end
        end else begin
            $display("Error: invalid dimension input.");
        end
        $display("---------------------------------------");
        $finish;
    end
endmodule
