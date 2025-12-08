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
// Additional Comments: 仿真文件
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_matrix_add;
    // 信号定义
    reg  clk;
    reg  reset;
    reg  [2:0] m;
    reg  [2:0] n;
    reg  [199:0] matrixA;
    reg  [199:0] matrixB;
    wire [199:0] aPlusB;
    wire valid;
    wire addError;

    // 实例化 DUT (Design Under Test)
    AddUnit dut (
        .clk(clk), 
        .reset(reset), 
        .m(m), 
        .n(n), 
        .matrixA(matrixA), 
        .matrixB(matrixB), 
        .aPlusB(aPlusB), 
        .valid(valid), 
        .addError(addError)
    );

    // ============================================================
    // 【关键修改】：将 output 改为 inout
    // ============================================================
    task automatic set_elem(inout reg [199:0] mat, input integer r, input integer c, input [7:0] val);
        integer idx;
        begin
            // 计算索引：(行 * 列数 + 列) * 数据位宽
            idx = (r*5 + c)*8;
            mat[idx +: 8] = val;
        end
    endtask

    integer i, j, idx;

    initial begin
        // 1. 初始化信号
        clk = 1'b0;
        reset = 1'b0;
        m = 3'd2;
        n = 3'd3;
        
        // 必须初始化矩阵为0，避免不定态
        matrixA = {200{1'b0}};
        matrixB = {200{1'b0}};

        // 2. 设置 Matrix A 的值
        // 现在使用的是 inout，每次调用都会保留之前设置的值
        set_elem(matrixA, 0, 0, 8'd1);
        set_elem(matrixA, 0, 1, 8'd2);
        set_elem(matrixA, 0, 2, 8'd3);
        set_elem(matrixA, 1, 0, 8'd3);
        set_elem(matrixA, 1, 1, 8'd4);
        set_elem(matrixA, 1, 2, 8'd5);

        // 3. 设置 Matrix B 的值
        set_elem(matrixB, 0, 0, 8'd3);
        set_elem(matrixB, 0, 1, 8'd3);
        set_elem(matrixB, 0, 2, 8'd3);
        set_elem(matrixB, 1, 0, 8'd2);
        set_elem(matrixB, 1, 1, 8'd2);
        set_elem(matrixB, 1, 2, 8'd2);

        // 4. 等待逻辑稳定
        #10; 

        // 5. 打印结果
        $display("---------------------------------------");
        $display("Simulation Result:");
        $display("Dimensions: %0d x %0d", m, n);
        $display("Status: valid=%0d, addError=%0d", valid, addError);
        $display("---------------------------------------");

        if (valid) begin
            $display("Matrix C (Result):");
            for (i = 0; i < m; i = i + 1) begin
                for (j = 0; j < n; j = j + 1) begin
                    idx = (i*5 + j)*8;
                    // 使用 %4d 对齐打印，看起来更整齐
                    $write("%4d ", aPlusB[idx +: 8]);
                end
                $display(""); // 换行
            end
        end else begin
            $display("Error: Dimension mismatch or invalid input.");
        end
        $display("---------------------------------------");
        
        $finish;
    end

endmodule