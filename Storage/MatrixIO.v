module matrixIO (
    input clk,
    input rst,
    input writeEnable,
    input [7:0] dimX,
    input [7:0] dimY,
    input [25*8-1:0] writeData,      // 单个矩阵数据 (200 bits)
    output reg [5*25*8-1:0] readData,// 5个矩阵扁平化数据 (1000 bits)
    output reg [2:0] fillState
);

    // Parameter definition
    localparam MAX_SCALE = 25;
    localparam MAX_MATRIX = 5;
    localparam MAX_ELEM = 25;
    localparam ELEM_WIDTH = 8;
    
    // Width of a single matrix: 25 * 8 = 200 bits
    localparam MATRIX_WIDTH = MAX_ELEM * ELEM_WIDTH; 
    // Width of all 5 matrices: 5 * 200 = 1000 bits
    localparam TOTAL_WIDTH = MAX_MATRIX * MATRIX_WIDTH;

    // Internal memory: 2D array
    // mem[dimension index] contains all 5 matrices flattened
    reg [TOTAL_WIDTH-1:0] mem [0:MAX_SCALE-1];

    // Internal variables
    reg [4:0] scaleIdx;
    reg [2:0] scalePtr [0:MAX_SCALE-1]; 
    reg [2:0] scaleCnt [0:MAX_SCALE-1]; 

    // Auxiliary signal
    wire [4:0] current_scale_idx;
    wire valid_dim;
    
    // Loop variables declaration (Moved to outside)
    integer i;

    assign valid_dim = (dimX >= 1 && dimX <= 5) && (dimY >= 1 && dimY <= 5);
    assign current_scale_idx = valid_dim ? ((dimY - 1)*5 + (dimX - 1)) : 5'd0;

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            // 1. 仅复位控制信号，不要复位 mem 数组
            for(i=0; i<MAX_SCALE; i=i+1) begin
                scalePtr[i] <= 3'd0;
                scaleCnt[i] <= 3'd0;
            end
            scaleIdx <= 5'd0;
            readData <= {TOTAL_WIDTH{1'b0}};
            fillState <= 3'd0;
        end else begin
            // Cache current index
            scaleIdx <= current_scale_idx;

            // --- Write logic ---
            if(writeEnable && valid_dim) begin
                // 使用 Part-Select 语法直接更新宽向量中的某一段
                // mem[行][高位:低位] <= 数据
                mem[current_scale_idx][(scalePtr[current_scale_idx] * MATRIX_WIDTH) +: MATRIX_WIDTH] <= writeData;

                // Update counter
                if(scaleCnt[current_scale_idx] < MAX_MATRIX) begin
                    scaleCnt[current_scale_idx] <= scaleCnt[current_scale_idx] + 1'b1;
                end

                // Update pointer
                if(scalePtr[current_scale_idx] == MAX_MATRIX - 1) begin
                    scalePtr[current_scale_idx] <= 3'd0;
                end else begin
                    scalePtr[current_scale_idx] <= scalePtr[current_scale_idx] + 1'b1;
                end
            end

            // --- Read logic ---
            // 直接读取整行数据，无需循环拼接
            // 注意：这里读取的是上一个周期的 current_scale_idx 还是当前的？
            // 你的原逻辑是同步读，这里保持一致，直接读出当前索引指向的整行
            readData <= mem[current_scale_idx];

            // --- State output ---
            fillState <= scaleCnt[current_scale_idx];
        end
    end

endmodule