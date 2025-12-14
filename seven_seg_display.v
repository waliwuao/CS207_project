`timescale 1ns / 1ps

module seven_seg_display (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [2:0] mode_state,
    input  wire       force_mode_pulse,
    input  wire       calc_op_pulse,
    input  wire [7:0] calc_op_char,
    input  wire       calc_op_hold,
    input  wire [7:0] calc_op_hold_char,
    input  wire       scalar_disp_en,
    input  wire [3:0] scalar_val,
    input  wire       countdown_en,
    input  wire [4:0] countdown_sec,
    output reg  [6:0] seg,
    output reg  [3:0] an
);

    localparam MODE_DEFAULT = 3'd0;
    localparam MODE_STORE   = 3'd1;
    localparam MODE_GEN     = 3'd2;
    localparam MODE_SHOW    = 3'd3;
    localparam MODE_CALC    = 3'd4;
    localparam MODE_SETUP   = 3'd5;

    localparam [31:0] DISPLAY_CYCLES = 32'd50_000_000; // 1s @ 50MHz; for 100MHz adjust if needed

    reg  [2:0]  prev_mode_state;
    reg         display_active;
    reg  [31:0] display_counter;

    reg  [1:0]  mux_counter;
    reg  [15:0] mux_timer;

    // Latch what to display during the 1-second window
    reg        latched_is_calc_op;
    reg  [2:0] latched_mode_state;
    reg  [7:0] latched_calc_op_char;

    wire should_display;
    assign should_display = countdown_en || display_active || (mode_state == MODE_CALC && calc_op_hold) || scalar_disp_en;

    // Detect mode change OR forced mode pulse OR CALC op selection pulse
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prev_mode_state       <= MODE_DEFAULT;
            display_active        <= 1'b0;
            display_counter       <= 32'd0;
            latched_is_calc_op    <= 1'b0;
            latched_mode_state    <= MODE_DEFAULT;
            latched_calc_op_char  <= 8'h00;
        end else begin
            prev_mode_state <= mode_state;

            if (calc_op_pulse) begin
                display_active       <= 1'b1;
                display_counter      <= 32'd0;
                latched_is_calc_op   <= 1'b1;
                latched_mode_state   <= MODE_CALC;
                latched_calc_op_char <= calc_op_char;
            end else if (force_mode_pulse) begin
                display_active       <= 1'b1;
                display_counter      <= 32'd0;
                latched_is_calc_op   <= 1'b0;
                latched_mode_state   <= mode_state;
            end else if (mode_state != MODE_DEFAULT && mode_state != prev_mode_state) begin
                display_active     <= 1'b1;
                display_counter    <= 32'd0;
                latched_is_calc_op <= 1'b0;
                latched_mode_state <= mode_state;
            end else if (display_active) begin
                if (display_counter < DISPLAY_CYCLES - 1) begin
                    display_counter <= display_counter + 1'b1;
                end else begin
                    display_active  <= 1'b0;
                    display_counter <= 32'd0;
                end
            end
        end
    end

    // Display multiplex clock
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mux_timer   <= 16'd0;
            mux_counter <= 2'd0;
        end else begin
            if (mux_timer < 16'd49999) begin
                mux_timer <= mux_timer + 1'b1;
            end else begin
                mux_timer   <= 16'd0;
                mux_counter <= mux_counter + 1'b1;
            end
        end
    end

    function automatic [6:0] seg_for_letter;
        input [7:0] ch;
        begin
            case (ch)
                "S": seg_for_letter = 7'b1101101;
                "T": seg_for_letter = 7'b0000111;
                "O": seg_for_letter = 7'b0111111;
                "G": seg_for_letter = 7'b0111101;
                "E": seg_for_letter = 7'b1111001;
                "N": seg_for_letter = 7'b0110111;
                "H": seg_for_letter = 7'b1110110;
                "C": seg_for_letter = 7'b0111001;
                "A": seg_for_letter = 7'b1110111;
                "L": seg_for_letter = 7'b0111000;
                "U": seg_for_letter = 7'b0111110;
                "P": seg_for_letter = 7'b1100111;
                "B": seg_for_letter = 7'b1111100; // b-like for scalar mul
                "J": seg_for_letter = 7'b0011110;
                default: seg_for_letter = 7'b0000000;
            endcase
        end
    endfunction

    function automatic [6:0] seg_for_hex;
        input [3:0] v;
        begin
            case (v)
                4'h0: seg_for_hex = 7'b0111111;
                4'h1: seg_for_hex = 7'b0000110;
                4'h2: seg_for_hex = 7'b1011011;
                4'h3: seg_for_hex = 7'b1001111;
                4'h4: seg_for_hex = 7'b1100110;
                4'h5: seg_for_hex = 7'b1101101;
                4'h6: seg_for_hex = 7'b1111101;
                4'h7: seg_for_hex = 7'b0000111;
                4'h8: seg_for_hex = 7'b1111111;
                4'h9: seg_for_hex = 7'b1101111;
                4'hA: seg_for_hex = 7'b1110111;
                4'hB: seg_for_hex = 7'b1111100;
                4'hC: seg_for_hex = 7'b0111001;
                4'hD: seg_for_hex = 7'b1011110;
                4'hE: seg_for_hex = 7'b1111001;
                default: seg_for_hex = 7'b1110001;
            endcase
        end
    endfunction

    wire [3:0] countdown_tens;
    wire [3:0] countdown_ones;
    assign countdown_tens = (countdown_sec >= 5'd10) ? 4'd1 : 4'd0;
    assign countdown_ones = (countdown_sec >= 5'd10) ? (countdown_sec - 5'd10) : countdown_sec[3:0];

    always @* begin
        // default off
        an  = 4'b0000;
        seg = 7'b0000000;

        if (should_display) begin
            // Countdown overlay has highest priority
            if (countdown_en) begin
                case (mux_counter)
                    2'd2: begin an = 4'b0100; seg = seg_for_hex(countdown_tens); end
                    2'd3: begin an = 4'b1000; seg = seg_for_hex(countdown_ones); end
                    default: begin an = 4'b0000; seg = 7'b0000000; end
                endcase
            // Scalar live display during CALC scalar-entry: show op (digit0) + scalar (digit3)
            end else if (!display_active && scalar_disp_en) begin
                case (mux_counter)
                    2'd0: begin an = 4'b0001; seg = seg_for_letter(calc_op_hold_char); end
                    2'd3: begin an = 4'b1000; seg = seg_for_hex((scalar_val <= 4'h9) ? scalar_val : 4'hE); end
                    default: begin an = 4'b0000; seg = 7'b0000000; end
                endcase
            // 1) During 1-second window, show latched
            end else if (display_active && latched_is_calc_op) begin
                case (mux_counter)
                    2'd0: begin an = 4'b0001; seg = seg_for_letter(latched_calc_op_char); end
                    default: begin an = 4'b0000; seg = 7'b0000000; end
                endcase
            end else if (display_active) begin
                case (latched_mode_state)
                    MODE_STORE: begin
                        case (mux_counter)
                            2'd0: begin an = 4'b0001; seg = seg_for_letter("S"); end
                            2'd1: begin an = 4'b0010; seg = seg_for_letter("T"); end
                            2'd2: begin an = 4'b0100; seg = seg_for_letter("O"); end
                            default: begin an = 4'b0000; seg = 7'b0000000; end
                        endcase
                    end
                    MODE_GEN: begin
                        case (mux_counter)
                            2'd0: begin an = 4'b0001; seg = seg_for_letter("G"); end
                            2'd1: begin an = 4'b0010; seg = seg_for_letter("E"); end
                            2'd2: begin an = 4'b0100; seg = seg_for_letter("N"); end
                            default: begin an = 4'b0000; seg = 7'b0000000; end
                        endcase
                    end
                    MODE_SHOW: begin
                        case (mux_counter)
                            2'd0: begin an = 4'b0001; seg = seg_for_letter("S"); end
                            2'd1: begin an = 4'b0010; seg = seg_for_letter("H"); end
                            2'd2: begin an = 4'b0100; seg = seg_for_letter("O"); end
                            default: begin an = 4'b0000; seg = 7'b0000000; end
                        endcase
                    end
                    MODE_CALC: begin
                        case (mux_counter)
                            2'd0: begin an = 4'b0001; seg = seg_for_letter("C"); end
                            2'd1: begin an = 4'b0010; seg = seg_for_letter("A"); end
                            2'd2: begin an = 4'b0100; seg = seg_for_letter("L"); end
                            default: begin an = 4'b0000; seg = 7'b0000000; end
                        endcase
                    end
                    MODE_SETUP: begin
                        case (mux_counter)
                            2'd0: begin an = 4'b0001; seg = seg_for_letter("S"); end
                            2'd1: begin an = 4'b0010; seg = seg_for_letter("E"); end
                            2'd2: begin an = 4'b0100; seg = seg_for_letter("T"); end
                            default: begin an = 4'b0000; seg = 7'b0000000; end
                        endcase
                    end
                    default: begin an = 4'b0000; seg = 7'b0000000; end
                endcase
            end else begin
                // 2) Hold display (CALC op letter)
                case (mux_counter)
                    2'd0: begin an = 4'b0001; seg = seg_for_letter(calc_op_hold_char); end
                    default: begin an = 4'b0000; seg = 7'b0000000; end
                endcase
            end
        end
    end

endmodule