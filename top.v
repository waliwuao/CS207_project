`timescale 1ns / 1ps

module top #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BLINK_HZ    = 4
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       btn,
    input  wire [4:0] mode_sw,
    input  wire       uart_rx,
    output wire [7:0] mode_led,
    output wire [6:0] seg,
    output wire [3:0] an,
    output wire       uart_tx
);

    // --------------------
    // Mode definitions
    // --------------------
    localparam MODE_DEFAULT = 3'd0;
    localparam MODE_STORE   = 3'd1;
    localparam MODE_GEN     = 3'd2;
    localparam MODE_SHOW    = 3'd3;
    localparam MODE_CALC    = 3'd4;
    localparam MODE_SETUP   = 3'd5;

    // Matrix packing helpers
    localparam integer MATRIX_WIDTH = 25 * 8;
    localparam integer MATRIX_DEPTH = 5;
    localparam integer TOTAL_WIDTH  = MATRIX_WIDTH * MATRIX_DEPTH;

    // Constant concat helper
    function [199:0] pack25;
        input [7:0] d0;  input [7:0] d1;  input [7:0] d2;  input [7:0] d3;  input [7:0] d4;
        input [7:0] d5;  input [7:0] d6;  input [7:0] d7;  input [7:0] d8;  input [7:0] d9;
        input [7:0] d10; input [7:0] d11; input [7:0] d12; input [7:0] d13; input [7:0] d14;
        input [7:0] d15; input [7:0] d16; input [7:0] d17; input [7:0] d18; input [7:0] d19;
        input [7:0] d20; input [7:0] d21; input [7:0] d22; input [7:0] d23; input [7:0] d24;
        begin
            pack25 = {d24,d23,d22,d21,d20,d19,d18,d17,d16,d15,
                      d14,d13,d12,d11,d10,d9,d8,d7,d6,d5,
                      d4,d3,d2,d1,d0};
        end
    endfunction

    // Hard-coded demo matrices
    localparam [199:0] MAT_2X2_A = pack25(
        8'd1, 8'd2, 8'd3, 8'd4, 8'd0,
        8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
        8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
        8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
        8'd0, 8'd0, 8'd0, 8'd0, 8'd0
    );

    localparam [199:0] MAT_2X2_B = pack25(
        8'd5, 8'd6, 8'd7, 8'd8, 8'd0,
        8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
        8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
        8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
        8'd0, 8'd0, 8'd0, 8'd0, 8'd0
    );

    localparam [199:0] MAT_3X3_A = pack25(
        8'd1, 8'd2, 8'd3, 8'd4, 8'd5,
        8'd6, 8'd7, 8'd8, 8'd9, 8'd0,
        8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
        8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
        8'd0, 8'd0, 8'd0, 8'd0, 8'd0
    );

    // --------------------
    // Basic mode handling
    // --------------------
    reg [2:0]  mode_state;
    wire        error_active;
    wire        blink_bit;
    wire        btn_pulse;

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
                mode_state <= mode_state; // Stay in mode until reset
            end
        end
    end

    led_display u_led (
        .mode_state(mode_state),
        .error_active(error_active),
        .blink_bit(blink_bit),
        .mode_sw(mode_sw),
        .mode_led(mode_led)
    );

    seven_seg_display u_seg (
        .clk(clk),
        .rst_n(rst_n),
        .mode_state(mode_state),
        .seg(seg),
        .an(an)
    );

    // --------------------
    // UART RX for SHOW input
    // --------------------
    wire [7:0] rx_data;
    wire       rx_done;

    UartRx #(
        .CLK_FREQ(CLK_FREQ_HZ)
    ) u_rx (
        .clk(clk),
        .rstN(rst_n),
        .rx(uart_rx),
        .rxData(rx_data),
        .rxDone(rx_done)
    );

    function automatic [7:0] decode_digit;
        input [7:0] v;
        begin
            if (v >= 8'h30 && v <= 8'h39) begin
                decode_digit = v - 8'h30;
            end else begin
                decode_digit = 8'd0;
            end
        end
    endfunction

    // --------------------
    // Matrix storage
    // --------------------
    reg               storage_we;
    reg [7:0]         storage_dimX;
    reg [7:0]         storage_dimY;
    reg [199:0]       storage_wdata;
    wire [TOTAL_WIDTH-1:0] storage_rdata;
    wire [2:0]        storage_count;

    // SHOW controller signals needed for matrixIO
    reg [7:0] req_m, req_n;

    matrixIO u_matrix_store (
        .clk(clk),
        .rst(~rst_n),
        .writeEnable(storage_we),
        .dimX(storage_dimX),
        .dimY(storage_dimY),
        .writeData(storage_wdata),
        .readData(storage_rdata),
        .fillState(storage_count)
    );

    reg [3:0] init_step;
    reg       init_active;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            init_step    <= 4'd0;
            init_active  <= 1'b1;
            storage_we   <= 1'b0;
            storage_dimX <= 8'd1;
            storage_dimY <= 8'd1;
            storage_wdata<= {MATRIX_WIDTH{1'b0}};
        end else begin
            storage_we <= 1'b0;
            if (init_active) begin
                case (init_step)
                    4'd0: begin
                        storage_dimX  <= 8'd2;
                        storage_dimY  <= 8'd2;
                        storage_wdata <= MAT_2X2_A;
                        storage_we    <= 1'b1;
                        init_step     <= 4'd1;
                    end
                    4'd1: init_step <= 4'd2;
                    4'd2: begin
                        storage_dimX  <= 8'd2;
                        storage_dimY  <= 8'd2;
                        storage_wdata <= MAT_2X2_B;
                        storage_we    <= 1'b1;
                        init_step     <= 4'd3;
                    end
                    4'd3: init_step <= 4'd4;
                    4'd4: begin
                        storage_dimX  <= 8'd3;
                        storage_dimY  <= 8'd3;
                        storage_wdata <= MAT_3X3_A;
                        storage_we    <= 1'b1;
                        init_step     <= 4'd5;
                    end
                    default: begin
                        init_active <= 1'b0;
                    end
                endcase
            end else begin
                // Sync storage dimensions with SHOW mode requests
                storage_dimX <= req_m;
                storage_dimY <= req_n;
            end
        end
    end

    // --------------------
    // SHOW controller (Fixed Logic)
    // --------------------
    localparam SHOW_IDLE      = 3'd0;
    localparam SHOW_WAIT_M    = 3'd1;
    localparam SHOW_WAIT_N    = 3'd2;
    localparam SHOW_PREP      = 3'd3;
    localparam SHOW_SEND_ARM  = 3'd4;
    localparam SHOW_SEND_WAIT = 3'd5;

    localparam PROMPT_WAIT1   = 2'd0;
    localparam PROMPT_WAIT2   = 2'd1;
    localparam PROMPT_DISPLAY = 2'd2;

    reg [2:0] show_state;
    reg [2:0] show_cursor;
    reg       show_send_pulse;
    reg       prompt_start;
    reg [1:0] prompt_sel;
    reg       prompt_req;
    reg [1:0] prompt_req_sel;
    
    // Timer to wait for storage lookup
    reg [1:0] prep_timer;

    wire [7:0] rx_digit;
    wire       rx_digit_ok;
    wire       rx_is_ignore;

    // Detect UART busyness to avoid collision
    wire show_tx_busy;  // Defined later
    wire mode_uart_busy; // Defined later

    assign rx_digit     = decode_digit(rx_data);
    assign rx_digit_ok  = (rx_digit >= 8'd1) && (rx_digit <= 8'd5);
    // Ignore CR (0D), LF (0A), Space (20)
    assign rx_is_ignore = (rx_data == 8'h0D) || (rx_data == 8'h0A) || (rx_data == 8'h20);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            show_state      <= SHOW_IDLE;
            req_m           <= 8'd1;
            req_n           <= 8'd1;
            show_cursor     <= 3'd0;
            show_send_pulse <= 1'b0;
            prompt_start    <= 1'b0;
            prompt_sel      <= PROMPT_WAIT1;
            prompt_req      <= 1'b0;
            prompt_req_sel  <= PROMPT_WAIT1;
            prep_timer      <= 2'd0;
        end else begin
            show_send_pulse <= 1'b0;
            prompt_start    <= 1'b0;

            // If we leave SHOW mode, cancel pending prompts
            if (mode_state != MODE_SHOW) begin
                prompt_req <= 1'b0;
            end

            case (show_state)
                SHOW_IDLE: begin
                    show_cursor <= 3'd0;
                    prep_timer  <= 2'd0;
                    if (mode_state == MODE_SHOW) begin
                        // Entry point: Request "Wait1"
                        prompt_req     <= 1'b1;
                        prompt_req_sel <= PROMPT_WAIT1;
                        show_state     <= SHOW_WAIT_M;
                    end
                end

                SHOW_WAIT_M: begin
                    show_cursor <= 3'd0;
                    if (mode_state != MODE_SHOW) begin
                        show_state <= SHOW_IDLE;
                    end else if (rx_done) begin
                        if (rx_digit_ok) begin
                            // Valid M -> Request "Wait2" -> Wait for N
                            req_m          <= rx_digit;
                            prompt_req     <= 1'b1;
                            prompt_req_sel <= PROMPT_WAIT2;
                            show_state     <= SHOW_WAIT_N;
                        end else if (!rx_is_ignore) begin
                            // Invalid input (and not newline) -> Re-send "Wait1"
                            prompt_req     <= 1'b1;
                            prompt_req_sel <= PROMPT_WAIT1;
                            show_state     <= SHOW_WAIT_M;
                        end
                        // If rx_is_ignore, do nothing (stay in WAIT_M)
                    end
                end

                SHOW_WAIT_N: begin
                    show_cursor <= 3'd0;
                    if (mode_state != MODE_SHOW) begin
                        show_state <= SHOW_IDLE;
                    end else if (rx_done) begin
                        if (rx_digit_ok) begin
                            // Valid N -> Request "Display" -> Prepare to send
                            req_n          <= rx_digit;
                            prompt_req     <= 1'b1;
                            prompt_req_sel <= PROMPT_DISPLAY;
                            show_state     <= SHOW_PREP;
                            prep_timer     <= 2'd0;
                        end else if (!rx_is_ignore) begin
                            // Invalid input -> Re-send "Wait2"
                            prompt_req     <= 1'b1;
                            prompt_req_sel <= PROMPT_WAIT2;
                            show_state     <= SHOW_WAIT_N;
                        end
                    end
                end

                SHOW_PREP: begin
                    // Wait a few cycles for req_m/n to propagate to matrixIO
                    // and for storage_count to settle.
                    show_cursor <= 3'd0;
                    if (mode_state != MODE_SHOW) begin
                        show_state <= SHOW_IDLE;
                    end else begin
                        if (prep_timer < 2'd3) begin
                            prep_timer <= prep_timer + 1'b1;
                        end else begin
                            if (storage_count == 3'd0) begin
                                // No matrices found -> Restart with "Wait1"
                                prompt_req     <= 1'b1;
                                prompt_req_sel <= PROMPT_WAIT1;
                                show_state     <= SHOW_WAIT_M;
                            end else begin
                                show_state <= SHOW_SEND_ARM;
                            end
                        end
                    end
                end

                SHOW_SEND_ARM: begin
                    if (mode_state != MODE_SHOW) begin
                        show_state <= SHOW_IDLE;
                    end else if (show_cursor >= storage_count) begin
                        // Done sending all matrices -> Restart with "Wait1"
                        prompt_req     <= 1'b1;
                        prompt_req_sel <= PROMPT_WAIT1;
                        show_state     <= SHOW_WAIT_M;
                    end else if (!show_tx_busy && !prompt_req && !mode_uart_busy) begin
                        // UART free, prompt done -> Trigger Matrix Send
                        show_send_pulse <= 1'b1;
                        show_state      <= SHOW_SEND_WAIT;
                    end
                end

                SHOW_SEND_WAIT: begin
                    if (mode_state != MODE_SHOW) begin
                        show_state <= SHOW_IDLE;
                    end else if (!show_tx_busy) begin
                        // Matrix transmission finished
                        show_cursor <= show_cursor + 1'b1;
                        show_state  <= SHOW_SEND_ARM;
                    end
                end

                default: show_state <= SHOW_IDLE;
            endcase

            // Dispatch prompt request when UART is clear
            if (!show_tx_busy && !mode_uart_busy && prompt_req && mode_state == MODE_SHOW) begin
                prompt_sel   <= prompt_req_sel;
                prompt_start <= 1'b1;
                prompt_req   <= 1'b0;
            end
        end
    end

    // --------------------
    // Output Multiplexing & TX modules
    // --------------------

    wire [199:0] show_matrix_slice;
    assign show_matrix_slice = storage_rdata[(show_cursor * MATRIX_WIDTH) +: MATRIX_WIDTH];

    wire prompt_uart_tx;
    wire prompt_uart_busy;
    wire matrix_uart_tx;
    reg  matrix_tx_busy;

    assign show_tx_busy = prompt_uart_busy || matrix_tx_busy;

    ShowUartTx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(115200)
    ) u_show_prompt (
        .clk(clk),
        .uartTxRstN(rst_n),
        .sendOne(1'b0),
        .promptStart(prompt_start),
        .promptSel(prompt_sel),
        .uartTx(prompt_uart_tx),
        .busy(prompt_uart_busy)
    );

    MatrixUartTx u_show_matrix (
        .clk(clk),
        .uartTxRstN(rst_n),
        .sendOne(show_send_pulse),
        .matrixData(show_matrix_slice),
        .m(req_m),
        .n(req_n),
        .id({5'b0, show_cursor} + 8'd1),
        .ifID(1'b1),
        .ifNM(1'b1),
        .uartTx(matrix_uart_tx)
    );

    wire mode_uart_tx;

    ModeUartNotifier #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ)
    ) u_mode_uart (
        .clk(clk),
        .rst_n(rst_n),
        .mode_state(mode_state),
        .uart_tx(mode_uart_tx),
        .busy(mode_uart_busy)
    );

    // Matrix Busy Detection Logic
    localparam integer SHOW_BAUD_RATE      = 115200;
    localparam integer SHOW_BIT_CYCLES     = CLK_FREQ_HZ / SHOW_BAUD_RATE;
    localparam integer SHOW_IDLE_BIT_GUARD = 12;
    localparam integer SHOW_IDLE_CYCLES    = SHOW_BIT_CYCLES * SHOW_IDLE_BIT_GUARD;

    reg [31:0] matrix_idle_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            matrix_tx_busy <= 1'b0;
            matrix_idle_cnt<= 32'd0;
        end else if (mode_state != MODE_SHOW) begin
            matrix_tx_busy <= 1'b0;
            matrix_idle_cnt<= 32'd0;
        end else begin
            // Arm busy flag on pulse
            if (show_send_pulse && !matrix_tx_busy) begin
                matrix_tx_busy <= 1'b1;
                matrix_idle_cnt<= 32'd0;
            end

            if (matrix_tx_busy) begin
                if (matrix_uart_tx) begin // Active High idle implies we look for high
                    // Wait, UART idle is HIGH. If TX is HIGH, we count. 
                    // If TX is LOW (start bit/data 0), we reset.
                    if (matrix_idle_cnt < SHOW_IDLE_CYCLES) begin
                        matrix_idle_cnt <= matrix_idle_cnt + 1'b1;
                    end
                end else begin
                    matrix_idle_cnt <= 32'd0;
                end

                if (matrix_idle_cnt >= SHOW_IDLE_CYCLES) begin
                    matrix_tx_busy <= 1'b0;
                    matrix_idle_cnt<= 32'd0;
                end
            end else begin
                matrix_idle_cnt <= 32'd0;
            end
        end
    end

    wire show_uart_sel_prompt;
    assign show_uart_sel_prompt = prompt_uart_busy || prompt_start;
    
    assign uart_tx = (mode_state == MODE_SHOW)
                   ? (show_uart_sel_prompt ? prompt_uart_tx : matrix_uart_tx)
                   : mode_uart_tx;

endmodule