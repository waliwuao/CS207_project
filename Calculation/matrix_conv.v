`timescale 1ns / 1ps

module ConvolutionUnit (
    input             clk,
    input             reset,
    input             start,
    input      [71:0]  kernelMatrix, // 3x3 kernel
    output reg [7:0]  out_m,
    output reg [7:0]  out_n,
    output reg [639:0] matrix_out, // 8x10 result
    output reg         valid,
    output reg [15:0]  cycleCount
);

    localparam OUT_ROWS = 8;
    localparam OUT_COLS = 10;
    
    // State machine
    localparam IDLE = 2'd0;
    localparam CALC = 2'd1;
    localparam DONE = 2'd2;
    
    reg [1:0] state;
    reg [3:0] row, col;
    reg [1:0] k_r, k_c;
    reg [15:0] acc;
    
    // ROM interface
    reg [3:0] rom_x, rom_y;
    wire [3:0] rom_data;
    
    input_image_rom u_rom (
        .clk(clk),
        .x(rom_x),
        .y(rom_y),
        .data_out(rom_data)
    );
    
    // Kernel unpacking
    reg [7:0] kernel [0:2][0:2];
    integer i, j;
    always @* begin
        for (i=0; i<3; i=i+1) begin
            for (j=0; j<3; j=j+1) begin
                kernel[i][j] = kernelMatrix[((i*3+j)*8) +: 8];
            end
        end
    end

    reg [3:0] wait_rom; // Delay for ROM read
    wire [15:0] next_acc;
    assign next_acc = acc + rom_data * kernel[k_r][k_c];
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            valid <= 1'b0;
            cycleCount <= 16'd0;
            out_m <= 8'd8;
            out_n <= 8'd10;
            matrix_out <= 640'd0;
            row <= 0; col <= 0;
            k_r <= 0; k_c <= 0;
            acc <= 0;
            wait_rom <= 0;
            rom_x <= 0; rom_y <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    if (start) begin
                        state <= CALC;
                        cycleCount <= 16'd0;
                        row <= 0; col <= 0;
                        k_r <= 0; k_c <= 0;
                        acc <= 0;
                        wait_rom <= 0;
                    end
                end
                
                CALC: begin
                    cycleCount <= cycleCount + 1'b1;
                    
                    // Address setup phase
                    if (wait_rom == 0) begin
                        rom_x <= row + k_r;
                        rom_y <= col + k_c;
                        wait_rom <= 1;
                    end else if (wait_rom == 1) begin
                        // Wait for ROM latency
                        wait_rom <= 2;
                    end else if (wait_rom == 2) begin
                        // Data available from ROM
                        // Perform MAC
                        acc <= next_acc;
                        
                        wait_rom <= 0;
                        
                        // Increment counters
                        if (k_c == 2) begin
                            k_c <= 0;
                            if (k_r == 2) begin
                                k_r <= 0;
                                // Pixel done, store result
                                // matrix_out is flat. Row 0 first.
                                // Index = (row * 10 + col) * 8
                                matrix_out[((row * 10 + col) * 8) +: 8] <= next_acc[7:0]; 
                                
                                acc <= 0;
                                
                                if (col == 9) begin
                                    col <= 0;
                                    if (row == 7) begin
                                        state <= DONE;
                                    end else begin
                                        row <= row + 1;
                                    end
                                end else begin
                                    col <= col + 1;
                                end
                            end else begin
                                k_r <= k_r + 1;
                            end
                        end else begin
                            k_c <= k_c + 1;
                        end
                    end
                end
                
                DONE: begin
                    valid <= 1'b1;
                    if (start) begin
                         state <= CALC;
                         valid <= 1'b0;
                         cycleCount <= 16'd0;
                         row <= 0; col <= 0;
                         k_r <= 0; k_c <= 0;
                         acc <= 0;
                         wait_rom <= 0;
                    end
                end
            endcase
        end
    end

endmodule

