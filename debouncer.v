`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/12/09 15:18:02
// Design Name: 
// Module Name: debouncer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module debouncer #(
    parameter CNT_MAX = 21'd1_999_999,
    parameter CNT_WIDTH = 21
)(
    input wire clk,
    input wire rst_n,
    input wire key_in,
    output reg key_flag
);

    reg [CNT_WIDTH-1:0] cnt_20ms;

    always @(posedge clk or negedge rst_n) begin
        if (rst_n == 1'b0) begin
            cnt_20ms <= 0;
        end
        else if (key_in == 1'b0) begin
            cnt_20ms <= 0;
        end
        else if (cnt_20ms == CNT_MAX && key_in == 1'b1) begin
            cnt_20ms <= cnt_20ms; 
        end
        else begin
            cnt_20ms <= cnt_20ms + 1'b1; // 正在消抖计数
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (rst_n == 1'b0) begin
            key_flag <= 1'b0;
        end
        else if (cnt_20ms == CNT_MAX - 1'b1) begin
            key_flag <= 1'b1;
        end
        else begin
            key_flag <= 1'b0;
        end
    end

endmodule