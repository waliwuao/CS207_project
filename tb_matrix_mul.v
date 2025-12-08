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


module tb_matrix_mul;
    reg  clk;
    reg  reset;
    reg  [2:0] a_m;
    reg  [2:0] a_n;
    reg  [2:0] b_m;
    reg  [2:0] b_n;
    reg  [199:0] matrixA;
    reg  [199:0] matrixB;
    wire [2:0] c_m;
    wire [2:0] c_n;
    wire [399:0] aMulB;
    wire valid;
    wire mul_error;

    MatrixMultiplyUnit dut (
        .clk(clk), .reset(reset),
        .a_m(a_m), .a_n(a_n), .b_m(b_m), .b_n(b_n),
        .matrixA(matrixA), .matrixB(matrixB), .c_m(c_m), .c_n(c_n), .aMulB(aMulB), .valid(valid), .mulError(mul_error)
    );

    // 仿照 tb_matrix_add：inout 便于多次写入同一矩阵
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
        a_m = 3'd2; a_n = 3'd3;
        b_m = 3'd3; b_n = 3'd2;
        matrixA = {200{1'b0}};
        matrixB = {200{1'b0}};

        set_elem(matrixA, 0, 0, 8'd1);
        set_elem(matrixA, 0, 1, 8'd2);
        set_elem(matrixA, 0, 2, 8'd3);
        set_elem(matrixA, 1, 0, 8'd3);
        set_elem(matrixA, 1, 1, 8'd4);
        set_elem(matrixA, 1, 2, 8'd5);

        set_elem(matrixB, 0, 0, 8'd1);
        set_elem(matrixB, 0, 1, 8'd0);
        set_elem(matrixB, 1, 0, 8'd2);
        set_elem(matrixB, 1, 1, 8'd1);
        set_elem(matrixB, 2, 0, 8'd3);
        set_elem(matrixB, 2, 1, 8'd2);

        #10;

        $display("---------------------------------------");
        $display("Matrix Multiply Result:");
        $display("A dims: %0d x %0d, B dims: %0d x %0d", a_m, a_n, b_m, b_n);
        $display("Status: valid=%0d, mul_error=%0d", valid, mul_error);
        $display("Output dims: %0d x %0d", c_m, c_n);
        $display("---------------------------------------");

        if (valid && !mul_error) begin
            for (i = 0; i < c_m; i = i + 1) begin
                for (j = 0; j < c_n; j = j + 1) begin
                    idx = (i*5 + j)*16;
                    $write("%6d ", aMulB[idx +: 16]);
                end
                $display("");
            end
        end else begin
            $display("Error: dimension mismatch.");
        end
        $display("---------------------------------------");
        $finish;
    end
endmodule
