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

module tb_matrix_conv;
    reg  clk;
    reg  reset;
    reg  [2:0] in_m;
    reg  [2:0] in_n;
    reg  [1:0] k_m;
    reg  [1:0] k_n;
    reg  [399:0] matrices_in;
    reg  [71:0]  kernelMatrix;
    wire [2:0] out_m;
    wire [2:0] out_n;
    wire [399:0] matrices_out;
    wire valid;
    wire [9:0] cycleCount;

    ConvolutionUnit dut (
        .clk(clk), .reset(reset), .in_m(in_m), .in_n(in_n), .k_m(k_m), .k_n(k_n),
        .matrices_in(matrices_in), .kernelMatrix(kernelMatrix), .out_m(out_m), .out_n(out_n), .matrices_out(matrices_out), .valid(valid), .cycleCount(cycleCount)
    );

    task automatic set_in_elem(inout reg [399:0] mat_pair, input integer r, input integer c, input [7:0] val);
        integer idx;
        begin
            idx = (r*5 + c)*8; // always matrix0 slot
            mat_pair[idx +: 8] = val;
        end
    endtask

    task automatic set_k_elem(inout reg [71:0] mat, input integer r, input integer c, input [7:0] val);
        integer idx;
        begin
            idx = (r*3 + c)*8;
            mat[idx +: 8] = val;
        end
    endtask

    integer i, j, idx;

    initial begin
        clk = 1'b0;
        reset = 1'b0;
        in_m = 3'd4;
        in_n = 3'd4;
        k_m  = 2'd2;
        k_n  = 2'd2;
        matrices_in = {400{1'b0}};
        kernelMatrix  = {72{1'b0}};

        set_in_elem(matrices_in, 0, 0, 8'd1);
        set_in_elem(matrices_in, 0, 1, 8'd2);
        set_in_elem(matrices_in, 0, 2, 8'd3);
        set_in_elem(matrices_in, 0, 3, 8'd4);
        set_in_elem(matrices_in, 1, 0, 8'd5);
        set_in_elem(matrices_in, 1, 1, 8'd6);
        set_in_elem(matrices_in, 1, 2, 8'd7);
        set_in_elem(matrices_in, 1, 3, 8'd8);
        set_in_elem(matrices_in, 2, 0, 8'd9);
        set_in_elem(matrices_in, 2, 1, 8'd10);
        set_in_elem(matrices_in, 2, 2, 8'd11);
        set_in_elem(matrices_in, 2, 3, 8'd12);
        set_in_elem(matrices_in, 3, 0, 8'd13);
        set_in_elem(matrices_in, 3, 1, 8'd14);
        set_in_elem(matrices_in, 3, 2, 8'd15);
        set_in_elem(matrices_in, 3, 3, 8'd16);

        set_k_elem(kernelMatrix, 0, 0, 8'd1);
        set_k_elem(kernelMatrix, 0, 1, 8'd1);
        set_k_elem(kernelMatrix, 1, 0, 8'd1);
        set_k_elem(kernelMatrix, 1, 1, 8'd1);

        #10;

        $display("---------------------------------------");
        $display("Convolution Result:");
        $display("Input dims: %0d x %0d, Kernel dims: %0d x %0d", in_m, in_n, k_m, k_n);
        $display("Status: valid=%0d, cycleCount=%0d", valid, cycleCount);
        $display("Output dims: %0d x %0d", out_m, out_n);
        $display("---------------------------------------");

        if (valid) begin
            for (i = 0; i < out_m; i = i + 1) begin
                for (j = 0; j < out_n; j = j + 1) begin
                    idx = (i*5 + j)*8;
                    $write("%4d ", matrices_out[idx +: 8]);
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
