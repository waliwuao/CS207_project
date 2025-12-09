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

module tb_matrix_scalar_mul;
    reg  clk;
    reg  reset;
    reg  [2:0] m;
    reg  [2:0] n;
    reg  [3:0] scalarValue;
    reg  [199:0] matrix_in;
    wire [199:0] matrix_out;
    wire valid;

    ScalarMultiplyUnit dut (
        .clk(clk), 
        .reset(reset), 
        .m(m), 
        .n(n), 
        .scalarValue(scalarValue), 
        .matrix_in(matrix_in), 
        .matrix_out(matrix_out), 
        .valid(valid)
    );

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
        m = 3'd2;
        n = 3'd3;
        scalarValue = 4'd3;

        matrix_in = {200{1'b0}};

        set_elem(matrix_in, 0, 0, 8'd1);
        set_elem(matrix_in, 0, 1, 8'd2);
        set_elem(matrix_in, 0, 2, 8'd3);
        set_elem(matrix_in, 1, 0, 8'd3);
        set_elem(matrix_in, 1, 1, 8'd4);
        set_elem(matrix_in, 1, 2, 8'd5);

        #10;

        $display("---------------------------------------");
        $display("Scalar Multiply Result:");
        $display("Dimensions: %0d x %0d, scalar=%0d", m, n, scalarValue);
        $display("Status: valid=%0d", valid);
        $display("---------------------------------------");

        if (valid) begin
            for (i = 0; i < m; i = i + 1) begin
                for (j = 0; j < n; j = j + 1) begin
                    idx = (i*5 + j)*8;
                    $write("%4d ", matrix_out[idx +: 8]);
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
