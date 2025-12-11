`timescale 1ns / 1ps

module seven_seg_display (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [2:0] mode_state,
    output reg  [6:0] seg,
    output reg  [3:0] an
);

    localparam MODE_DEFAULT = 3'd0;
    localparam MODE_STORE   = 3'd1;
    localparam MODE_GEN     = 3'd2;
    localparam MODE_SHOW    = 3'd3;
    localparam MODE_CALC    = 3'd4;
    localparam MODE_SETUP   = 3'd5;

    reg [2:0] prev_mode_state;
    reg       display_active;
    reg [31:0] display_counter;
    localparam DISPLAY_CYCLES = 50_000_000;
    reg [1:0] mux_counter; 
    reg [15:0] mux_timer;

    // Detect mode change
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prev_mode_state <= MODE_DEFAULT;
            display_active <= 1'b0;
            display_counter <= 32'd0;
        end else begin
            prev_mode_state <= mode_state;
            if (mode_state != MODE_DEFAULT && mode_state != prev_mode_state) begin
                display_active <= 1'b1;
                display_counter <= 32'd0;
            end else if (display_active) begin
                if (display_counter < DISPLAY_CYCLES - 1) begin
                    display_counter <= display_counter + 1'b1;
                end else begin
                    display_active <= 1'b0;
                    display_counter <= 32'd0;
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mux_timer <= 16'd0;
            mux_counter <= 2'd0;
        end else begin
            if (mux_timer < 16'd49999) begin 
                mux_timer <= mux_timer + 1'b1;
            end else begin
                mux_timer <= 16'd0;
                mux_counter <= mux_counter + 1'b1;
            end
        end
    end

    always @* begin
        if (display_active) begin
            // Ä¬ÈÏ¹Ø±Õ (an=1111, seg=0)
            an = 4'b0000; 
            seg = 7'b0000000;
            
            case (mode_state)
                MODE_STORE: begin
                    case (mux_counter)
                        2'd0: begin an = 4'b0001; seg = 7'b1101101; end // S
                        2'd1: begin an = 4'b0010; seg = 7'b0000111; end // T
                        2'd2: begin an = 4'b0100; seg = 7'b0111111; end // O
                        2'd3: begin an = 4'b0000; seg = 7'b0000000; end
                    endcase
                end
                MODE_GEN: begin
                    case (mux_counter)
                        2'd0: begin an = 4'b0001; seg = 7'b0111101; end // G
                        2'd1: begin an = 4'b0010; seg = 7'b1111001; end // E
                        2'd2: begin an = 4'b0100; seg = 7'b0110111; end // N
                        2'd3: begin an = 4'b0000; seg = 7'b0000000; end
                    endcase
                end
                MODE_SHOW: begin
                    case (mux_counter)
                        2'd0: begin an = 4'b0001; seg = 7'b1101101; end // S
                        2'd1: begin an = 4'b0010; seg = 7'b1110110; end // H
                        2'd2: begin an = 4'b0100; seg = 7'b0111111; end // O
                        2'd3: begin an = 4'b0000; seg = 7'b0000000; end
                    endcase
                end
                MODE_CALC: begin
                    case (mux_counter)
                        2'd0: begin an = 4'b0001; seg = 7'b0111001; end // C
                        2'd1: begin an = 4'b0010; seg = 7'b1110111; end // A
                        2'd2: begin an = 4'b0100; seg = 7'b0111000; end // L
                        2'd3: begin an = 4'b0000; seg = 7'b0000000; end
                    endcase
                end
                MODE_SETUP: begin
                    case (mux_counter)
                        2'd0: begin an = 4'b0001; seg = 7'b1101101; end // S
                        2'd1: begin an = 4'b0010; seg = 7'b1111001; end // E
                        2'd2: begin an = 4'b0100; seg = 7'b0000111; end // T
                        2'd3: begin an = 4'b0000; seg = 7'b0000000; end
                    endcase
                end
                default: begin
                    an = 4'b0000;
                    seg = 7'b0000000;
                end
            endcase
        end else begin
            an = 4'b0000;
            seg = 7'b0000000; 
        end
    end

endmodule           