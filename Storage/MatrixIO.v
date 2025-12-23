module matrixIO (
    input clk,                   // Clock signal
    input rst,                   // Reset signal
    input writeEnable,           // Write enable signal
    input [7:0] dimX,            // Matrix X dimension (1-5) (Rows)
    input [7:0] dimY,            // Matrix Y dimension (1-5) (Cols)
    input [2:0] user_max_limit,  // User defined max limit
    input [2:0] readIdx,         // Logical index to read (0..user_max_limit-1)
    input [25*8-1:0] writeData,  // Data to write (single matrix, 25 elements)
    output reg [25*8-1:0] readData, // Flattened data of 1 matrix
    output reg [2:0] fillState   // Fill state (number of matrices stored)
);

    // Parameter definition
    localparam MAX_SCALE = 25;   // Total number of dimension combinations (5x5)
    localparam MAX_MATRIX = 3;   // Maximum number of matrices stored for each dimension
    localparam MAX_ELEM = 25;    // Maximum number of elements in each matrix
    localparam ELEM_WIDTH = 8;   // Bit width of each element

    // Internal memory
    // mem[dimension index][matrix slot][element index]
    reg [ELEM_WIDTH-1:0] mem [0:MAX_SCALE-1] [0:MAX_MATRIX-1] [0:MAX_ELEM-1];

    // Internal variables
    reg [2:0] scalePtr [0:MAX_SCALE-1]; 
    reg [2:0] scaleCnt [0:MAX_SCALE-1]; 
    reg [2:0] last_limit;        // Track limit changes

    // Effective limit
    wire [2:0] effective_limit;
    assign effective_limit = (user_max_limit > MAX_MATRIX) ? MAX_MATRIX : 
                             (user_max_limit == 0) ? 3'd1 : user_max_limit;

    // Dimension validity and Index Calculation
    wire valid_dim;
    wire [4:0] current_scale_idx;

    // Check bounds strictly (1-5)
    assign valid_dim = (dimX >= 8'd1 && dimX <= 8'd5) && (dimY >= 8'd1 && dimY <= 8'd5);

    // Calculate index: (Rows-1) + (Cols-1)*5. 
    // Ensure index is forced to 0 if dimensions are invalid to prevent out-of-bounds aliasing logic
    assign current_scale_idx = valid_dim ? ((dimY - 8'd1)*5 + (dimX - 8'd1)) : 5'd0;

    // Loop variables
    integer i, j, k, elemIdx, eIdx;
    integer baseSlot, srcSlot;

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            // Reset logic
            for(i=0; i<MAX_SCALE; i=i+1) begin
                scalePtr[i] <= 3'd0; 
                scaleCnt[i] <= 3'd0; 
            end
            // Note: Resetting entire 'mem' is expensive and not strictly necessary if pointers are reset
            // but can be done if required. Pointers being 0 effectively clears logic.
            fillState <= 3'd0;
            readData <= {(MAX_ELEM*ELEM_WIDTH){1'b0}};
            last_limit <= 3'd3; 
        end else begin
            
            // --- Limit Change Logic ---
            if (effective_limit != last_limit) begin
                last_limit <= effective_limit;
                for(i=0; i<MAX_SCALE; i=i+1) begin
                    // If current count exceeds new limit, clamp it and reset pointer
                    if (scaleCnt[i] > effective_limit) begin
                        scaleCnt[i] <= effective_limit;
                        scalePtr[i] <= 3'd0; // Reset pointer to ensure circular buffer consistency
                    end
                    // If pointer is out of bounds (shouldn't happen if logic is correct, but safe to check)
                    if (scalePtr[i] >= effective_limit) begin
                        scalePtr[i] <= 3'd0;
                    end
                end
            end else begin
                // --- Write Logic ---
                // Only write if dimensions are strictly valid. 
                // Using valid_dim ensures we never write to index 0 due to invalid inputs (like 0x0).
                if(writeEnable && valid_dim) begin
                    // 1. Write Data
                    for(elemIdx=0; elemIdx<MAX_ELEM; elemIdx=elemIdx+1) begin
                        mem[current_scale_idx][scalePtr[current_scale_idx]][elemIdx] <= 
                            writeData[elemIdx*ELEM_WIDTH +: ELEM_WIDTH];
                    end

                    // 2. Update Counter
                    if(scaleCnt[current_scale_idx] < effective_limit) begin
                        scaleCnt[current_scale_idx] <= scaleCnt[current_scale_idx] + 1'b1;
                    end

                    // 3. Update Pointer (Circular Buffer)
                    if(scalePtr[current_scale_idx] >= effective_limit - 1) begin
                        scalePtr[current_scale_idx] <= 3'd0;
                    end else begin
                        scalePtr[current_scale_idx] <= scalePtr[current_scale_idx] + 1'b1;
                    end
                end
            end

            // --- Read Logic ---
            // Independent of write logic, updates every clock based on inputs dimX/dimY
            // Read Pointer Calculation based on Buffer State
            if (scaleCnt[current_scale_idx] >= effective_limit) begin
                baseSlot = scalePtr[current_scale_idx]; // Oldest data is at current write pointer
            end else begin
                baseSlot = 0; // Oldest data is at 0
            end

            // Data Output
            if (readIdx < scaleCnt[current_scale_idx]) begin
                srcSlot = baseSlot + readIdx;
                if (srcSlot >= effective_limit) begin
                    srcSlot = srcSlot - effective_limit;
                end
                
                for (eIdx = 0; eIdx < MAX_ELEM; eIdx = eIdx + 1) begin
                    readData[(eIdx*ELEM_WIDTH) +: ELEM_WIDTH] <=
                        mem[current_scale_idx][srcSlot][eIdx];
                end
            end else begin
                readData <= {(MAX_ELEM*ELEM_WIDTH){1'b0}};
            end

            // State Output
            fillState <= scaleCnt[current_scale_idx];
        end
    end

endmodule
