
`timescale 1ns / 1ps

module debouncer #(
    parameter integer CLK_FREQ = 50_000_000
)(
    input  wire clk,
    input  wire rst_n,
    input  wire key_in,
    output reg  key_flag
);

    // Simple 20ms debounce
    localparam CNT_MAX = CLK_FREQ / 50; 
    reg [31:0] cnt;
    reg key_in_d0, key_in_d1;
    reg key_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 0;
            key_flag <= 0;
            key_in_d0 <= 0;
            key_in_d1 <= 0;
            key_state <= 0;
        end else begin
            // Synchronize input
            key_in_d0 <= key_in;
            key_in_d1 <= key_in_d0;

            key_flag <= 0; // Default pulse low

            if (key_in_d1 != key_state) begin
                if (cnt < CNT_MAX) begin
                    cnt <= cnt + 1;
                end else begin
                    key_state <= key_in_d1;
                    cnt <= 0;
                    if (key_in_d1 == 1'b1) begin // Assuming active high button press
                        key_flag <= 1'b1;
                    end
                end
            end else begin
                cnt <= 0;
            end
        end
    end

endmodule