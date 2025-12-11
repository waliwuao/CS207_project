`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 
// Design Name: 
// Module Name: tb_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Testbench for top module - UART Matrix Data Transmission
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module tb_top();

    // 时钟和复位信�??
    reg clk;
    reg uart_tx_rst_n;
    reg send_one;
    
    // 输出信号
    wire uart_tx;
    wire uart_tx_work;
    
    // 实例化顶层模�??
    top uut (
        .clk(clk),
        .uart_tx_rst_n(uart_tx_rst_n),
        .send_one(send_one),
        .uart_tx(uart_tx),
        .uart_tx_work(uart_tx_work)
    );
    
    // 时钟生成 - 100MHz
    parameter CLK_PERIOD = 10; // 10ns周期
    always begin
        clk = 1'b0;
        #(CLK_PERIOD / 2);
        clk = 1'b1;
        #(CLK_PERIOD / 2);
    end
    
    initial begin
    send_one=1'b0;
    #200 send_one=1'b1;
    end
    initial begin
    #300 send_one=1'b0;
    end
 
    initial begin
        clk = 1'b0;
        uart_tx_rst_n = 1'b0;
        send_one = 1'b0;
        
        // 复位
        #100;
        uart_tx_rst_n = 1'b1;
        
        #10000;
        
    end
    
    // 波形记录（VCD文件，可在波形查看器中打�??�??
    initial begin
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);
    end

endmodule
