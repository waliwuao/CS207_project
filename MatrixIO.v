module matrixIO (
    input clk,                   // Clock signal
    input rst,                   // Reset signal
    input writeEnable,           // Write enable signal
    input [7:0] dimX,            // Matrix X dimension (1-5)
    input [7:0] dimY,            // Matrix Y dimension (1-5)
    input [25*8-1:0] writeData,  // Data to write (single matrix, 25 elements)
    output reg [5*25*8-1:0] readData, // Flattened data of 5 matrices
    output reg [2:0] fillState   // Fill state (number of matrices stored)
);

    // Parameter definition
    localparam MAX_SCALE = 25;   // Total number of dimension combinations (5x5)
    localparam MAX_MATRIX = 5;   // Maximum number of matrices stored for each dimension
    localparam MAX_ELEM = 25;    // Maximum number of elements in each matrix
    localparam ELEM_WIDTH = 8;   // Bit width of each element

    // Internal memory
    // mem[dimension index][matrix slot][element index]
    reg [ELEM_WIDTH-1:0] mem [0:MAX_SCALE-1] [0:MAX_MATRIX-1] [0:MAX_ELEM-1];

    // Internal variables
    reg [4:0] scaleIdx;          // Index of current dimension (0-24)
    reg [2:0] scalePtr [0:MAX_SCALE-1]; 
    reg [2:0] scaleCnt [0:MAX_SCALE-1]; 

    // Auxiliary signal: Calculate the index of the combination logic for delay avoidance in sequential logic
    wire [4:0] current_scale_idx;
    wire valid_dim;

    // Dimension validity judgment
    assign valid_dim = (dimX >= 1 && dimX <= 5) && (dimY >= 1 && dimY <= 5);
    // Index calculation: (Y-1)*5 + (X-1) mapped to 0-24
    assign current_scale_idx = valid_dim ? ((dimY - 1)*5 + (dimX - 1)) : 5'd0;

    // Main state machine logic
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            integer i, j, k;
            // Reset logic
            for(i=0; i<MAX_SCALE; i=i+1) begin
                for(j=0; j<MAX_MATRIX; j=j+1) begin
                    for(k=0; k<MAX_ELEM; k=k+1) begin
                        mem[i][j][k] <= {ELEM_WIDTH{1'b0}};
                    end
                end
                scalePtr[i] <= 3'd0; // Reset pointer
                scaleCnt[i] <= 3'd0; // Reset counter
            end
            scaleIdx <= 5'd0;
            readData <= {(MAX_MATRIX*MAX_ELEM*ELEM_WIDTH){1'b0}};
            fillState <= 3'd0;
        end else begin
            // Update the index of the currently stored index for later use
            scaleIdx <= current_scale_idx;

            // --- Write logic ---
            if(writeEnable && valid_dim) begin
                integer elemIdx;
                // 1. Write data to the matrix slot pointed to by the pointer
                for(elemIdx=0; elemIdx<MAX_ELEM; elemIdx=elemIdx+1) begin
                    mem[current_scale_idx][scalePtr[current_scale_idx]][elemIdx] <= 
                        writeData[elemIdx*ELEM_WIDTH +: ELEM_WIDTH];
                end

                // 2. Update counter (saturate at MAX_MATRIX)
                if(scaleCnt[current_scale_idx] < MAX_MATRIX) begin
                    scaleCnt[current_scale_idx] <= scaleCnt[current_scale_idx] + 1'b1;
                end

                // 3. Update pointer (circular buffer: 0->1->2->3->4->0...)
                if(scalePtr[current_scale_idx] == MAX_MATRIX - 1) begin
                    scalePtr[current_scale_idx] <= 3'd0;
                end else begin
                    scalePtr[current_scale_idx] <= scalePtr[current_scale_idx] + 1'b1;
                end
            end

            // --- Read logic ---
            // 3. Flatten the data of all 5 matrices
            // Output format: [matrix4]...[matrix1][matrix0] (depending on bus convention, this is stored as matrix0)
            integer mIdx, eIdx;
            for(mIdx=0; mIdx < MAX_MATRIX; mIdx=mIdx+1) begin
                for(eIdx=0; eIdx < MAX_ELEM; eIdx=eIdx+1) begin
                    readData[(mIdx*MAX_ELEM*ELEM_WIDTH) + (eIdx*ELEM_WIDTH) +: ELEM_WIDTH] <= 
                        mem[current_scale_idx][mIdx][eIdx];
                end
            end

            // --- State output ---
            // Output the number of matrices filled in the current dimension (0 to 5)
            fillState <= scaleCnt[current_scale_idx];
        end
    end

endmodule