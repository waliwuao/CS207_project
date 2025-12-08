module matrixIO (
    input clk,       // Clock signal
    input rst,       // Reset signal
    input writeEnable,     // Write enable signal
    input [7:0] dimX,  // X dimension of the matrix
    input [7:0] dimY,  // Y dimension of the matrix
    input [24*8-1:0] writeData,  // Data to write to the matrix
    output reg [2*25*8-1:0] readData,  // Data read from the matrix
    output reg [1:0] fillState  // State of the matrix fill
);

localparam MAX_SCALE = 25;  // Maximum scale of the matrix
localparam MAX_MATRIX = 2;  // Maximum number of matrices
localparam MAX_ELEM = 25;  // Maximum number of elements in each matrix
localparam ELEM_WIDTH = 8;  // Width of each element in bits

reg [ELEM_WIDTH-1:0] mem [0:MAX_SCALE-1] [0:MAX_MATRIX-1] [0:MAX_ELEM-1];  // Memory to store the matrix elements
reg [4:0] scaleIdx;  // Index of the current scale
reg [0:MAX_SCALE-1] scalePtr;  // Pointer to the current matrix in the current scale
reg [1:0] scaleCnt [0:MAX_SCALE-1];  // Counter for the number of matrices filled in the current scale

// FSM to handle matrix operations
always @(posedge clk or posedge rst) begin
    if(rst) begin  // Reset
        integer i, j, k;
        for(i=0; i<MAX_SCALE; i=i+1) begin
            for(j=0; j<MAX_MATRIX; j=j+1) begin
                for(k=0; k<MAX_ELEM; k=k+1) begin
                    mem[i][j][k] <= 8'd0;
                end
            end
            scalePtr[i] <= 1'b0;
            scaleCnt[i] <= 2'd0;
        end
        scaleIdx <= 5'd0;
        readData <= {2*MAX_ELEM*ELEM_WIDTH{1'b0}};
        fillState <= 2'b00;
    end else begin
        // Calculate the index of the current scale based on the X and Y dimensions
        scaleIdx <= ((dimX >= 1 && dimX <=5) && (dimY >=1 && dimY <=5)) ? 
                    ((dimY - 1)*5 + (dimX - 1)) : 5'd0;
        // Write data to the matrix if the write enable signal is high and the dimensions are valid
        if(writeEnable && (dimX >=1 && dimX <=5) && (dimY >=1 && dimY <=5)) begin
            integer elemIdx;
            for(elemIdx=0; elemIdx<MAX_ELEM; elemIdx=elemIdx+1) begin
                mem[scaleIdx][scalePtr[scaleIdx]][elemIdx] <= writeData[elemIdx*ELEM_WIDTH +: ELEM_WIDTH];
            end
            // Increment the counter if the number of matrices filled in the current scale is less than 2
            if(scaleCnt[scaleIdx] < 2) begin
                scaleCnt[scaleIdx] <= scaleCnt[scaleIdx] + 1'b1;
            end
            // Toggle the pointer to the current matrix in the current scale
            scalePtr[scaleIdx] <= ~scalePtr[scaleIdx];
        end
        // Read data from the matrix and update the output signals
        integer rdIdx;
        for(rdIdx=0; rdIdx<MAX_ELEM; rdIdx=rdIdx+1) begin
            readData[rdIdx*ELEM_WIDTH +: ELEM_WIDTH] <= mem[scaleIdx][0][rdIdx];
            readData[(MAX_ELEM + rdIdx)*ELEM_WIDTH +: ELEM_WIDTH] <= mem[scaleIdx][1][rdIdx];
        end
        // Update the fill state based on the number of matrices filled in the current scale
        case(scaleCnt[scaleIdx])
            2'd0: fillState <= 2'b00;
            2'd1: fillState <= 2'b01;
            2'd2: fillState <= 2'b10;
            default: fillState <= 2'b00;
        endcase
    end
end

endmodule
