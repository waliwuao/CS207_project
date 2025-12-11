`timescale 1ns / 1ps


module error_blink #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer BLINK_HZ    = 4
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       btn_pulse,
    input  wire [4:0] mode_sw,
    input  wire [2:0] mode_state,
    output reg        error_active,
    output reg        blink_bit
);

    localparam MODE_DEFAULT = 3'd0;

    localparam integer ERROR_CYCLES      = CLK_FREQ_HZ;             // 1 second
    localparam integer BLINK_HALF_CYCLES = CLK_FREQ_HZ/(BLINK_HZ*2); // half period

    reg [31:0] error_counter;
    reg [31:0] blink_counter;

    // True when exactly one bit is set.
    function automatic is_one_hot;
        input [4:0] v;
        begin
            is_one_hot = (v != 5'b0) && ((v & (v - 1'b1)) == 5'b0);
        end
    endfunction

    // Error control and blink timers.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
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

                // Trigger error if in default mode and invalid switch on button press
                if (mode_state == MODE_DEFAULT && btn_pulse && !is_one_hot(mode_sw)) begin
                    error_active <= 1'b1;
                end
            end
        end
    end

endmodule
