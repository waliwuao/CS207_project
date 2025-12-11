`timescale 1ns / 1ps

module top #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BLINK_HZ    = 4
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       btn,
    input  wire [4:0] mode_sw,
    output wire [7:0] mode_led,
    output wire [6:0] seg,
    output wire [3:0] an,
    output wire       uart_tx
);

    localparam MODE_DEFAULT = 3'd0;
    localparam MODE_STORE   = 3'd1;
    localparam MODE_GEN     = 3'd2;
    localparam MODE_SHOW    = 3'd3;
    localparam MODE_CALC    = 3'd4;
    localparam MODE_SETUP   = 3'd5;

    reg [2:0]  mode_state;
    wire        error_active;
    wire        blink_bit;

    wire btn_pulse;

    function automatic [2:0] sw_to_mode;
        input [4:0] v;
        begin
            case (v)
                5'b00001: sw_to_mode = MODE_STORE;
                5'b00010: sw_to_mode = MODE_GEN;
                5'b00100: sw_to_mode = MODE_SHOW;
                5'b01000: sw_to_mode = MODE_CALC;
                5'b10000: sw_to_mode = MODE_SETUP;
                default:  sw_to_mode = MODE_DEFAULT;
            endcase
        end
    endfunction

    debouncer #(
        .CLK_FREQ(CLK_FREQ_HZ)
    ) u_db (
        .clk(clk),
        .rst_n(rst_n),
        .key_in(btn),
        .key_flag(btn_pulse)
    );

    // Error blink module (�ⲿģ�飬����ԭ��ʵ����)
    error_blink #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BLINK_HZ(BLINK_HZ)
    ) u_error (
        .clk(clk),
        .rst_n(rst_n),
        .btn_pulse(btn_pulse),
        .mode_sw(mode_sw),
        .mode_state(mode_state),
        .error_active(error_active),
        .blink_bit(blink_bit)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mode_state <= MODE_DEFAULT;
        end else begin
            // Mode transition only from default on a debounced button pulse.
            if (mode_state == MODE_DEFAULT) begin
                if (btn_pulse) begin
                    if ( (mode_sw == 5'b00001) ||
                         (mode_sw == 5'b00010) ||
                         (mode_sw == 5'b00100) ||
                         (mode_sw == 5'b01000) ||
                         (mode_sw == 5'b10000) )
                    begin
                        mode_state <= sw_to_mode(mode_sw);
                    end else begin
                        mode_state <= MODE_DEFAULT;
                    end
                end
            end else begin
                mode_state <= mode_state;
            end
        end
    end

    // LED display module (�ⲿģ�飬����ԭ��ʵ����)
    led_display u_led (
        .mode_state(mode_state),
        .error_active(error_active),
        .blink_bit(blink_bit),
        .mode_sw(mode_sw),
        .mode_led(mode_led)
    );

    // Seven segment display module
    seven_seg_display u_seg (
        .clk(clk),
        .rst_n(rst_n),
        .mode_state(mode_state),
        .seg(seg),
        .an(an)
    );

    // UART notifier: emits mode name on every mode entry (including DEFAULT)
    ModeUartNotifier #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ)
    ) u_mode_uart (
        .clk(clk),
        .rst_n(rst_n),
        .mode_state(mode_state),
        .uart_tx(uart_tx),
        .busy()
    );

endmodule
