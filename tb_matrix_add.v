`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: tb_matrix_add
// Description: 矩阵加法测试 Testbench
//////////////////////////////////////////////////////////////////////////////////

module tb_matrix_add;
    // 信号定义
    reg  clk;
    reg  reset;
    reg  [2:0] m;
    reg  [2:0] n;
    reg  [199:0] matrixA_in;
    reg  [199:0] matrixB_in;
    wire [199:0] matrix_out;
    wire valid;

    // 实例化 DUT (Design Under Test)
    AddUnit dut (
        .clk(clk), 
        .reset(reset), 
        .m(m), 
        .n(n), 
        .matrixA_in(matrixA_in),
        .matrixB_in(matrixB_in),
        .matrix_out(matrix_out), 
        .valid(valid)
    );

    // ============================================================
    // 任务定义：设置矩阵元素值
    // ============================================================
    // 注意：inout 参数会在任务结束时将值复制回调用变量
    task automatic set_elem;
        inout [199:0] mat; // 去掉 reg 关键字，让编译器自动推断
        input integer r;   // 行索引
        input integer c;   // 列索引
        input [7:0]   val; // 值
        integer idx;
        begin
            // 计算 1D 数组中的索引位置：(行 * 最大列数 + 列) * 位宽
            // MAX_DIM = 5, ELEM_WIDTH = 8
            idx = (r * 5 + c) * 8;
            mat[idx +: 8] = val;
        end
    endtask

    integer i, j, idx;

    initial begin
        // 1. 初始化信号
        clk = 1'b0;
        reset = 1'b0;
        m = 3'd2; // 设置为 2 行
        n = 3'd3; // 设置为 3 列
        
        // 必须初始化矩阵为0
        matrixA_in = {200{1'b0}};
        matrixB_in = {200{1'b0}};

        // 2. 设置 Matrix A 的值 (2x3)
        // 修正了调用：set_elem(矩阵, 行, 列, 值)
        // Row 0: 1, 2, 3
        set_elem(matrixA_in, 0, 0, 8'd1);
        set_elem(matrixA_in, 0, 1, 8'd2);
        set_elem(matrixA_in, 0, 2, 8'd3);
        // Row 1: 3, 4, 5
        set_elem(matrixA_in, 1, 0, 8'd3);
        set_elem(matrixA_in, 1, 1, 8'd4);
        set_elem(matrixA_in, 1, 2, 8'd5);

        // 3. 设置 Matrix B 的值 (2x3)
        // Row 0: 3, 3, 3
        set_elem(matrixB_in, 0, 0, 8'd3);
        set_elem(matrixB_in, 0, 1, 8'd3);
        set_elem(matrixB_in, 0, 2, 8'd3);
        // Row 1: 2, 2, 2
        set_elem(matrixB_in, 1, 0, 8'd2);
        set_elem(matrixB_in, 1, 1, 8'd2);
        set_elem(matrixB_in, 1, 2, 8'd2);

        // 4. 等待逻辑稳定 (因为是组合逻辑，稍微延时即可)
        #10; 

        // 5. 打印结果
        $display("");
        $display("=======================================");
        $display("Simulation Result:");
        $display("Dimensions: %0d x %0d", m, n);
        $display("Status: valid=%0d", valid);
        $display("=======================================");

        if (valid) begin
            $display("Matrix Result (A + B):");
            // 按照实际维度 m x n 打印
            for (i = 0; i < m; i = i + 1) begin
                $write("Row %0d: ", i);
                for (j = 0; j < n; j = j + 1) begin
                    idx = (i*5 + j)*8;
                    $write("%4d ", matrix_out[idx +: 8]);
                end
                $display(""); // 换行
            end
        end else begin
            $display("Error: Dimension mismatch or invalid input.");
        end
        $display("=======================================");
        
        $finish;
    end

endmodule