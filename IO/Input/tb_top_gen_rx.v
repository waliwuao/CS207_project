
`timescale 1ns/1ps

module tb_top_gen_rx;

    // clock / reset
    reg clk;
    reg uartRxRstN;
    reg uartTxRstN;

    // uart rx interface
    reg rx;
    reg rxStart;

    // outputs
    wire rxError;
    wire uart_tx;
    wire uart_tx_work;
    wire rxDone;
    wire [7:0] m;
    wire [7:0] n;
    wire [199:0] matrixData;
    wire isM;
    wire isN;
    wire isBusy;
    wire rxDoneWire;

    // instantiate DUT
    top_gen_rx dut (
        .clk(clk),
        .uartRxRstN(uartRxRstN),
        .uartTxRstN(uartTxRstN),
        .rx(rx),
        .rxStart(rxStart),
        .rxError(rxError),
        .uart_tx(uart_tx),
        .uart_tx_work(uart_tx_work)
        // .rxDone(rxDone)
    );

    // clock 100MHz
    always #5 clk = ~clk;

    // UART parameters (must match RTL)
    localparam BAUD = 115200;
    localparam BIT_TIME = 1_000_000_000 / BAUD;

    // UART send task (LSB first)
    task uart_send_byte(input [7:0] data);
        integer i;
        begin
            rx = 1'b0; // start bit
            #(BIT_TIME);
            for (i=0;i<8;i=i+1) begin
                rx = data[i];
                #(BIT_TIME);
            end
            rx = 1'b1; // stop bit
            #(BIT_TIME);
        end
    endtask

    initial begin
        // init
        clk = 0;
        rx  = 1'b1;
        rxStart = 1'b0;
        uartRxRstN = 1'b0;
        uartTxRstN = 1'b0;

        #100;
        uartRxRstN = 1'b1;
        uartTxRstN = 1'b1;

        // start RX
        #25;
        rxStart = 1'b1;
        #100;
        rxStart = 1'b0;
        #20;

        // send: m=2 n=3
        uart_send_byte("2");
        uart_send_byte(8'h20); // space
        uart_send_byte("3");
        uart_send_byte(8'h20);
        uart_send_byte("1");
        uart_send_byte(8'h0A);

        // wait processing
        #(BIT_TIME * 500);
        #25;
        rxStart = 1'b1;
        #100;
        rxStart = 1'b0;
        #20;

        // send: m=2 n=3
        uart_send_byte("2");
        uart_send_byte(8'h20); // space
        uart_send_byte("2");
        uart_send_byte(8'h20);
        uart_send_byte("1");
        uart_send_byte(8'h0A);

        // check internal registers
//        $display("M = %0d, N = %0d", dut.m, dut.n);
//        $display("MatrixData = %h", dut.matrixData);

        // $stop;
    end

endmodule
