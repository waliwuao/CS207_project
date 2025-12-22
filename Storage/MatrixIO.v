module matrixIO (
    input clk,                   // Clock signal
    input rst,                   // Reset signal
    input writeEnable,           // Write enable signal
    input [7:0] dimX,            // Matrix X dimension (1-5)
    input [7:0] dimY,            // Matrix Y dimension (1-5)
    input [2:0] user_max_limit,  // User defined max limit (Should be <= 3 now)
    input [25*8-1:0] writeData,  // Data to write (single matrix, 25 elements)
    output reg [3*25*8-1:0] readData, 
    output reg [2:0] fillState,   // Fill state
    output [74:0] matrixListInfo // Flattened count of all dimensions
);

    // Parameter definition
    localparam MAX_SCALE = 25;   // Total number of dimension combinations (5x5)
    localparam MAX_MATRIX = 3;   
    localparam MAX_ELEM = 25;    // Maximum number of elements in each matrix
    localparam ELEM_WIDTH = 8;   // Bit width of each element

    (* ram_style = "block" *) 
    reg [ELEM_WIDTH-1:0] mem [0:MAX_SCALE-1] [0:MAX_MATRIX-1] [0:MAX_ELEM-1];

    // Internal variables
    reg [4:0] scaleIdx;          // Index of current dimension
    reg [2:0] scalePtr [0:MAX_SCALE-1]; 
    reg [2:0] scaleCnt [0:MAX_SCALE-1]; 
    reg [2:0] last_limit;        

    // Loop indices
    integer i, j, k;
    integer elemIdx;
    integer mIdx;
    integer eIdx;
    integer baseSlot;
    integer srcSlot;

    // Auxiliary signals
    wire [4:0] current_scale_idx;
    wire valid_dim;
    wire [2:0] safe_limit;

    // Dimension validity and Index calculation
    assign valid_dim = (dimX >= 1 && dimX <= 5) && (dimY >= 1 && dimY <= 5);
    assign current_scale_idx = valid_dim ? ((dimY - 1)*5 + (dimX - 1)) : 5'd0;
    
    assign safe_limit = (user_max_limit > MAX_MATRIX) ? MAX_MATRIX[2:0] : user_max_limit;

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            for(i=0; i<MAX_SCALE; i=i+1) begin
                scalePtr[i] <= 3'd0; 
                scaleCnt[i] <= 3'd0; 
            end
            
            scaleIdx <= 5'd0;
            readData <= {(MAX_MATRIX*MAX_ELEM*ELEM_WIDTH){1'b0}};
            fillState <= 3'd0;
            last_limit <= 3'd3;

        end else begin
            scaleIdx <= current_scale_idx;

            if (safe_limit != last_limit) begin
                last_limit <= safe_limit;
                for(i=0; i<MAX_SCALE; i=i+1) begin
                    if (scaleCnt[i] > scalePtr[i]) begin
                        scaleCnt[i] <= 3'd0;
                        scalePtr[i] <= 3'd0;
                    end else begin
                        if (scaleCnt[i] > safe_limit) begin
                            scaleCnt[i] <= safe_limit;
                            scalePtr[i] <= 3'd0;
                        end
                    end
                end
            end else begin
                // --- Write logic ---
                if(writeEnable && valid_dim) begin
                    // 1. Write data
                    for(elemIdx=0; elemIdx<MAX_ELEM; elemIdx=elemIdx+1) begin
                        mem[current_scale_idx][scalePtr[current_scale_idx]][elemIdx] <= 
                            writeData[elemIdx*ELEM_WIDTH +: ELEM_WIDTH];
                    end

                    // 2. Update counter (limit by safe_limit)
                    if(scaleCnt[current_scale_idx] < safe_limit) begin
                        scaleCnt[current_scale_idx] <= scaleCnt[current_scale_idx] + 1'b1;
                    end

                    // 3. Update pointer (circular buffer)
                    if(scalePtr[current_scale_idx] >= safe_limit - 1) begin
                        scalePtr[current_scale_idx] <= 3'd0;
                    end else begin
                        scalePtr[current_scale_idx] <= scalePtr[current_scale_idx] + 1'b1;
                    end
                end
            end

            // --- Read logic ---
            if (scaleCnt[current_scale_idx] >= safe_limit) begin
                baseSlot = scalePtr[current_scale_idx];
            end else begin
                baseSlot = 0;
            end

            for (mIdx = 0; mIdx < MAX_MATRIX; mIdx = mIdx + 1) begin
                if (mIdx < scaleCnt[current_scale_idx]) begin
                    srcSlot = baseSlot + mIdx;
                    if (srcSlot >= safe_limit) begin
                        srcSlot = srcSlot - safe_limit;
                    end
                    
                    for (eIdx = 0; eIdx < MAX_ELEM; eIdx = eIdx + 1) begin
                        readData[(mIdx*MAX_ELEM*ELEM_WIDTH) + (eIdx*ELEM_WIDTH) +: ELEM_WIDTH] <=
                            mem[current_scale_idx][srcSlot][eIdx];
                    end
                end else begin
                    // Clear unused slots
                    for (eIdx = 0; eIdx < MAX_ELEM; eIdx = eIdx + 1) begin
                        readData[(mIdx*MAX_ELEM*ELEM_WIDTH) + (eIdx*ELEM_WIDTH) +: ELEM_WIDTH] <= {ELEM_WIDTH{1'b0}};
                    end
                end
            end

            // Output fill state
            fillState <= scaleCnt[current_scale_idx];
        end
    end

    // Flatten scaleCnt for matrixListInfo
    genvar gi;
    generate
        for (gi = 0; gi < MAX_SCALE; gi = gi + 1) begin : gen_info
            assign matrixListInfo[gi*3 +: 3] = scaleCnt[gi];
        end
    endgenerate

endmodule
