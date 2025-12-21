module random (
    input wire clk,
    input wire rst,
    input wire genEnable,
    input wire [7:0] max_val,
    output reg [25*8-1:0] readData
);

    reg [7:0] raw_random [0:24];
    wire [15:0] scaled_calc [0:24];
    integer i;

    wire [7:0] seed_salt [0:24];
    assign seed_salt[0] = 8'hA3; assign seed_salt[1] = 8'h12; assign seed_salt[2] = 8'hEF; assign seed_salt[3] = 8'h44;
    assign seed_salt[4] = 8'h9B; assign seed_salt[5] = 8'hC1; assign seed_salt[6] = 8'h28; assign seed_salt[7] = 8'h77;
    assign seed_salt[8] = 8'h3D; assign seed_salt[9] = 8'hF0; assign seed_salt[10] = 8'h05; assign seed_salt[11] = 8'h8A;
    assign seed_salt[12] = 8'h59; assign seed_salt[13] = 8'hB6; assign seed_salt[14] = 8'h6C; assign seed_salt[15] = 8'hD2;
    assign seed_salt[16] = 8'h1E; assign seed_salt[17] = 8'h83; assign seed_salt[18] = 8'h4F; assign seed_salt[19] = 8'h2A;
    assign seed_salt[20] = 8'h99; assign seed_salt[21] = 8'h55; assign seed_salt[22] = 8'h7E; assign seed_salt[23] = 8'hB0;
    assign seed_salt[24] = 8'hC4;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 25; i = i + 1) begin
                raw_random[i] <= seed_salt[i] ^ 8'h5A; 
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
