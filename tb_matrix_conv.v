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
    reg  [199:0] inputImage;
    reg  [71:0]  kernelMatrix;
    wire [2:0] out_m;
    wire [2:0] out_n;
    wire [399:0] convResult;
    wire valid;
    wire [9:0] cycleCount;
    wire done;
    wire dim_error;

    ConvolutionUnit dut (
        .clk(clk), .reset(reset), .in_m(in_m), .in_n(in_n), .k_m(k_m), .k_n(k_n),
        .inputImage(inputImage), .kernelMatrix(kernelMatrix), .out_m(out_m), .out_n(out_n), .convResult(convResult), .valid(valid), .cycleCount(cycleCount), .done(done), .dim_error(dim_error)
    );

    task automatic set_in_elem(inout reg [199:0] mat, input integer r, input integer c, input [7:0] val);
        integer idx;
        begin
            idx = (r*5 + c)*8;
            mat[idx +: 8] = val;
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
        inputImage = {200{1'b0}};
        kernelMatrix  = {72{1'b0}};

        set_in_elem(inputImage, 0, 0, 8'd1);
        set_in_elem(inputImage, 0, 1, 8'd2);
        set_in_elem(inputImage, 0, 2, 8'd3);
        set_in_elem(inputImage, 0, 3, 8'd4);
        set_in_elem(inputImage, 1, 0, 8'd5);
        set_in_elem(inputImage, 1, 1, 8'd6);
        set_in_elem(inputImage, 1, 2, 8'd7);
        set_in_elem(inputImage, 1, 3, 8'd8);
        set_in_elem(inputImage, 2, 0, 8'd9);
        set_in_elem(inputImage, 2, 1, 8'd10);
        set_in_elem(inputImage, 2, 2, 8'd11);
        set_in_elem(inputImage, 2, 3, 8'd12);
        set_in_elem(inputImage, 3, 0, 8'd13);
        set_in_elem(inputImage, 3, 1, 8'd14);
        set_in_elem(inputImage, 3, 2, 8'd15);
        set_in_elem(inputImage, 3, 3, 8'd16);

        set_k_elem(kernelMatrix, 0, 0, 8'd1);
        set_k_elem(kernelMatrix, 0, 1, 8'd1);
        set_k_elem(kernelMatrix, 1, 0, 8'd1);
        set_k_elem(kernelMatrix, 1, 1, 8'd1);

        #10;

        $display("---------------------------------------");
        $display("Convolution Result:");
        $display("Input dims: %0d x %0d, Kernel dims: %0d x %0d", in_m, in_n, k_m, k_n);
        $display("Status: valid=%0d, dim_error=%0d, done=%0d, cycleCount=%0d", valid, dim_error, done, cycleCount);
        $display("Output dims: %0d x %0d", out_m, out_n);
        $display("---------------------------------------");

        if (valid && !dim_error) begin
            for (i = 0; i < out_m; i = i + 1) begin
                for (j = 0; j < out_n; j = j + 1) begin
                    idx = (i*5 + j)*16;
                    $write("%6d ", convResult[idx +: 16]);
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
