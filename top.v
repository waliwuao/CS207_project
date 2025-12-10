`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/12/08 18:09:19
// Design Name: 
// Module Name: matrix
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

module top #(
    parameter integer CLK_FREQ_HZ = 50_000_000, // board clock frequency
    parameter integer BLINK_HZ    = 4           // blink rate during error window
)(
    input  wire       clk,
    input  wire       rst_n,      // active-low reset
    input  wire       btn,        // push button needing debounce
    input  wire [4:0] mode_sw,    // five DIP switches
    output reg  [4:0] mode_led    // five LEDs
);

    localparam MODE_DEFAULT = 3'd0;
    localparam MODE_STORE   = 3'd1;
    localparam MODE_GEN     = 3'd2;
    localparam MODE_SHOW    = 3'd3;
    localparam MODE_CALC    = 3'd4;
    localparam MODE_SETUP   = 3'd5;

    // 1 second error duration and blink divider.
    localparam integer ERROR_CYCLES      = CLK_FREQ_HZ;             // 1 second
    localparam integer BLINK_HALF_CYCLES = CLK_FREQ_HZ/(BLINK_HZ*2); // half period

    reg [2:0]  mode_state;
    reg        error_active;
    reg [31:0] error_counter;
    reg [31:0] blink_counter;
    reg        blink_bit;

    wire btn_pulse;

    // Use provided debouncer: emits a one-cycle key_flag after stable press.
    debouncer u_db (
        .clk(clk),
        .rst_n(rst_n),
        .key_in(btn),
        .key_flag(btn_pulse)
    );

    // True when exactly one bit is set.
    function automatic is_one_hot;
        input [4:0] v;
        begin
            is_one_hot = (v != 5'b0) && ((v & (v - 1'b1)) == 5'b0);
        end
    endfunction

    // Map one-hot switch to mode encoding.
    function automatic [2:0] sw_to_mode;
        input [4:0] v;
        begin
            case (v)
                5'b00001: sw_to_mode = MODE_STORE; // switch 0
                5'b00010: sw_to_mode = MODE_GEN;   // switch 1
                5'b00100: sw_to_mode = MODE_SHOW;  // switch 2
                5'b01000: sw_to_mode = MODE_CALC;  // switch 3
                5'b10000: sw_to_mode = MODE_SETUP; // switch 4
                default:  sw_to_mode = MODE_DEFAULT;
            endcase
        end
    endfunction

    // Mode control and blink timers.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mode_state    <= MODE_DEFAULT;
            error_active  <= 1'b0;
            error_counter <= 32'd0;
            blink_counter <= 32'd0;
            blink_bit     <= 1'b0;
        end else begin
            // Manage error window and blink toggle.
            if (error_active) begin
                if (error_counter < ERROR_CYCLES - 1) begin
                    error_counter <= error_counter + 1'b1;
                end else begin
                    error_active  <= 1'b0;
                    error_counter <= 32'd0;
                end

                if (blink_counter < BLINK_HALF_CYCLES - 1) begin
                    blink_counter <= blink_counter + 1'b1;
                end else begin
                    blink_counter <= 32'd0;
                    blink_bit     <= ~blink_bit;
                end
            end else begin
                error_counter <= 32'd0;
                blink_counter <= 32'd0;
                blink_bit     <= 1'b0;
            end

            // Mode transition only from default on a debounced button pulse.
            if (mode_state == MODE_DEFAULT) begin
                if (btn_pulse) begin
                    if (is_one_hot(mode_sw)) begin
                        mode_state   <= sw_to_mode(mode_sw);
                        error_active <= 1'b0;
                    end else begin
                        mode_state   <= MODE_DEFAULT;
                        error_active <= 1'b1; // trigger 1s blink
                    end
                end
            end else begin
                // Other modes hold until reset.
                mode_state <= mode_state;
            end
        end
    end

    // LED behavior.
    always @* begin
        if (mode_state == MODE_DEFAULT) begin
            if (error_active) begin
                mode_led = blink_bit ? 5'b11111 : 5'b00000; // blink all LEDs together
            end else begin
                mode_led = mode_sw; // follow switches
            end
        end else begin
            case (mode_state)
                MODE_STORE: mode_led = 5'b00001;
                MODE_GEN:   mode_led = 5'b00010;
                MODE_SHOW:  mode_led = 5'b00100;
                MODE_CALC:  mode_led = 5'b01000;
                MODE_SETUP: mode_led = 5'b10000;
                default:    mode_led = 5'b00000;
            endcase
        end
    end

endmodule