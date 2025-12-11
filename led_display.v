
`timescale 1ns / 1ps


module led_display (
    input  wire [2:0] mode_state,
    input  wire       error_active,
    input  wire       blink_bit,
    input  wire [4:0] mode_sw,
    output reg  [7:0] mode_led
);

    localparam MODE_DEFAULT = 3'd0;
    localparam MODE_STORE   = 3'd1;
    localparam MODE_GEN     = 3'd2;
    localparam MODE_SHOW    = 3'd3;
    localparam MODE_CALC    = 3'd4;
    localparam MODE_SETUP   = 3'd5;

    // LED behavior.
    always @* begin
        if (mode_state == MODE_DEFAULT) begin
            if (error_active) begin
                mode_led = blink_bit ? 8'b11111111 : 8'b00000000; // blink all eight LEDs together
            end else begin
                mode_led = {3'b000, mode_sw}; // follow switches on lower 5 LEDs
            end
        end else begin
            case (mode_state)
                MODE_STORE: mode_led = {3'b000, 5'b00001};
                MODE_GEN:   mode_led = {3'b000, 5'b00010};
                MODE_SHOW:  mode_led = {3'b000, 5'b00100};
                MODE_CALC:  mode_led = {3'b000, 5'b01000};
                MODE_SETUP: mode_led = {3'b000, 5'b10000};
                default:    mode_led = 8'b00000000;
            endcase
        end
    end

endmodule