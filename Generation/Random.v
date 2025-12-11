module random (
    input wire clk,                  // Clock signal
    input wire rst,                  // Reset signal
    input wire genEnable,            // Generator enable signal
    input wire [7:0] max_val,        // max value
    output reg [25*8-1:0] readData   // Flattened data of random number (25 elements)
);

    reg [7:0] raw_random [0:24];
    
    wire [15:0] scaled_calc [0:24];

    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 25; i = i + 1) begin
                raw_random[i] <= (i + 1) * 7 + 55;
            end
        end
        else if (genEnable) begin
            for (i = 0; i < 25; i = i + 1) begin
                raw_random[i] <= {raw_random[i][6:0], 
                                  raw_random[i][7] ^ raw_random[i][3] ^ raw_random[i][2] ^ raw_random[i][1]};
            end
        end
    end

    generate
        genvar j;
        for (j = 0; j < 25; j = j + 1) begin : limit_logic
            assign scaled_calc[j] = raw_random[j] * (max_val + 1'b1);
        end
    endgenerate

    always @(*) begin
        for (i = 0; i < 25; i = i + 1) begin
            readData[i*8 +: 8] = scaled_calc[i][15:8];
        end
    end

endmodule
