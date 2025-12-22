module matrixIO (
    input clk,                   // Clock signal
    input rst,                   // Reset signal
    input writeEnable,           // Write enable signal
    input [7:0] dimX,            // Matrix X dimension (1-5)
    input [7:0] dimY,            // Matrix Y dimension (1-5)
    input [2:0] user_max_limit,  // User defined max limit
    input [2:0] readIdx,         // Logical index to read (0..user_max_limit-1)
    input [25*8-1:0] writeData,  // Data to write (single matrix, 25 elements)
    output reg [25*8-1:0] readData, // Flattened data of 1 matrix
    output reg [2:0] fillState   // Fill state (number of matrices stored)
);

    // Parameter definition
    localparam MAX_SCALE = 25;   // Total number of dimension combinations (5x5)
    localparam MAX_MATRIX = 3;   // Maximum number of matrices stored for each dimension (Physical limit)
    localparam MAX_ELEM = 25;    // Maximum number of elements in each matrix
    localparam ELEM_WIDTH = 8;   // Bit width of each element

    // Internal memory
    // mem[dimension index][matrix slot][element index]
    reg [ELEM_WIDTH-1:0] mem [0:MAX_SCALE-1] [0:MAX_MATRIX-1] [0:MAX_ELEM-1];

    // Internal variables
    reg [4:0] scaleIdx;          // Index of current dimension (0-24)
    reg [2:0] scalePtr [0:MAX_SCALE-1]; 
    reg [2:0] scaleCnt [0:MAX_SCALE-1]; 
    reg [2:0] last_limit;        // Track limit changes

    // Procedural loop indices (must not be declared mid-block)
    integer i;
    integer j;
    integer k;
    integer elemIdx;
    integer eIdx;
    integer baseSlot;
    integer srcSlot;

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
            readData <= {(MAX_ELEM*ELEM_WIDTH){1'b0}};
            fillState <= 3'd0;
            last_limit <= 3'd3; // Default limit
        end else begin
            // Update the index of the currently stored index for later use
            scaleIdx <= current_scale_idx;

            if (user_max_limit != last_limit) begin
                // Limit changed: Re-evaluate all storage to prevent corruption
                last_limit <= user_max_limit;
                for(i=0; i<MAX_SCALE; i=i+1) begin
                    if (scaleCnt[i] > scalePtr[i]) begin
                        // Case 1: Wrapped buffer (e.g. 1, 2, 0).
                        // The physical layout depends on the OLD limit.
                        // It is incompatible with the NEW limit (read logic assumes new modulo).
                        // Must RESET to avoid reading garbage/zeros.
                        scaleCnt[i] <= 3'd0;
                        scalePtr[i] <= 3'd0;
                    end else begin
                        // Case 2: Linear buffer (0..Cnt-1).
                        // Layout is compatible with any limit >= Cnt.
                        if (scaleCnt[i] > user_max_limit) begin
                            // Shrinking (5->3): Truncate to fit new limit.
                            // Keeps indices 0..new_limit-1 (Oldest data).
                            scaleCnt[i] <= user_max_limit;
                            scalePtr[i] <= 3'd0; // Buffer is now full, next write wraps to 0
                        end
                        // Else: Growing (3->5) or fitting. Keep data as is.
                    end
                end
            end else begin
                // Normal Operation

                // --- Write logic ---
                if(writeEnable && valid_dim) begin
                    // 1. Write data to the matrix slot pointed to by the pointer
                    for(elemIdx=0; elemIdx<MAX_ELEM; elemIdx=elemIdx+1) begin
                        mem[current_scale_idx][scalePtr[current_scale_idx]][elemIdx] <= 
                            writeData[elemIdx*ELEM_WIDTH +: ELEM_WIDTH];
                    end

                    // 2. Update counter (saturate at user_max_limit)
                    if(scaleCnt[current_scale_idx] < user_max_limit) begin
                        scaleCnt[current_scale_idx] <= scaleCnt[current_scale_idx] + 1'b1;
                    end

                    // 3. Update pointer (circular buffer: 0->1->...->limit-1->0...)
                    if(scalePtr[current_scale_idx] >= user_max_limit - 1) begin
                        scalePtr[current_scale_idx] <= 3'd0;
                    end else begin
                        scalePtr[current_scale_idx] <= scalePtr[current_scale_idx] + 1'b1;
                    end
                end
            end

            // --- Read logic ---
            // Flatten the stored matrices in chronological order (oldest -> newest).
            // NOTE: Storage is a circular buffer; scalePtr points to the *next* write slot.
            // When full, the oldest matrix sits at scalePtr (the next one to be overwritten).
            // When not full, matrices are stored from slot 0..(count-1).
            if (scaleCnt[current_scale_idx] >= user_max_limit) begin
                baseSlot = scalePtr[current_scale_idx];
            end else begin
                baseSlot = 0;
            end

            // Map output slot readIdx -> source slot in circular buffer
            if (readIdx < scaleCnt[current_scale_idx]) begin
                srcSlot = baseSlot + readIdx;
                if (srcSlot >= user_max_limit) begin
                    srcSlot = srcSlot - user_max_limit;
                end
                for (eIdx = 0; eIdx < MAX_ELEM; eIdx = eIdx + 1) begin
                    readData[(eIdx*ELEM_WIDTH) +: ELEM_WIDTH] <=
                        mem[current_scale_idx][srcSlot][eIdx];
                end
            end else begin
                // Clear unused output slots
                for (eIdx = 0; eIdx < MAX_ELEM; eIdx = eIdx + 1) begin
                    readData[(eIdx*ELEM_WIDTH) +: ELEM_WIDTH] <= {ELEM_WIDTH{1'b0}};
                end
            end

            // --- State output ---
            // Output the number of matrices filled in the current dimension (0 to MAX_MATRIX)
            fillState <= scaleCnt[current_scale_idx];
        end
    end

endmodule