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
    // Storage power-on reset (POR)
    // --------------------
    // User reset (rst_n) is used to return to DEFAULT mode in this project.
    // To make stored/generated matrices survive that reset, matrixIO is only
    // reset once after power-up/configuration.
    reg        storage_por_done;
    reg [15:0] storage_por_cnt;
    wire       storage_rst;

    // Synthesis-friendly initialization for FPGA; in simulation this also
    // avoids X-propagation.
    initial begin
        storage_por_done = 1'b0;
        storage_por_cnt  = 16'd0;
    end

    // Hold storage in reset for a short time after rst_n is released the first
    // time. After that, never reset storage again.
    always @(posedge clk) begin
        if (!storage_por_done) begin
            if (!rst_n) begin
                storage_por_cnt <= 16'd0;
            end else if (storage_por_cnt == 16'd1023) begin
                storage_por_done <= 1'b1;
            end else begin
                storage_por_cnt <= storage_por_cnt + 1'b1;
            end
        end
    end

    assign storage_rst = ~storage_por_done;

    // --------------------
    // Forward Declarations
    // --------------------
    // UART RX
    wire [7:0] rx_data;
    wire       rx_done;
    
    // CALC State & Flow
    reg [2:0]  calc_state;
    reg [4:0]  calc_flow;
    reg [3:0]  conv_input_cnt;
    reg [2:0]  calc_sel_cursor; // Moved here
    reg [2:0]  show_cursor;     // Moved here
    
    // CALC Display & Control
    reg        calc_op_disp_pulse;
    reg [7:0]  calc_op_disp_char;
    wire       calc_op_hold;
    wire [7:0] calc_op_hold_char;
    reg        calc_scalar_disp_en;
    wire [3:0] calc_scalar_val;
    wire [15:0] conv_cycles;
    
    // UART Busy Signals (SHOW)
    wire       prompt_uart_busy;
    wire       show_tx_busy;
    wire       mode_uart_busy;
    wire       show_matrix_busy;
    wire       shared_matrix_busy; // Moved here for forward declaration
    
    // UART Busy Signals (CALC)
    wire       calc_info_uart_busy;
    wire       calc_matrix_tx_busy;
    wire       calc_result_tx_busy;
    wire       calc_op_tx_busy;
    wire       calc_word_txBusy;
    wire       calc_prompt_uart_busy;
    
    // CALC RX Signals
    wire       calc_nm_done;
    wire       calc_nm_error;
    wire [7:0] calc_nm_m;
    wire [7:0] calc_nm_n;
    wire       calc_id_done;
    wire       calc_id_error;
    wire [7:0] calc_id_val;
    
    // GEN Signals
    wire       gen_prompt_uart_busy;
    wire       gen_matrix_busy_wire;
    wire       gen_tx_busy;
    wire       gen_rx_done;
    wire       gen_rx_error;
    wire [7:0] gen_rx_m;
    wire [7:0] gen_rx_n;
    wire [7:0] gen_rx_cnt;

    // Forward Declarations for Output Multiplexing (used before definition)
    reg        calc_prompt_start;
    reg [2:0]  calc_prompt_sel;
    reg        calc_send_pulse;
    wire [199:0] calc_matrix_slice;

    reg        gen_prompt_start;
    reg [2:0]  gen_prompt_sel;
    reg        gen_send_pulse;
    reg [199:0] gen_matrix_latched;
    reg [7:0]   gen_m_latched;
    reg [7:0]   gen_n_latched;
    reg [7:0]   gen_id_latched;

    // --------------------
    // Mode definitions
    // --------------------
    localparam MODE_DEFAULT = 3'd0;
    localparam MODE_STORE   = 3'd1;
    localparam MODE_GEN     = 3'd2;
    localparam MODE_SHOW    = 3'd3;
    localparam MODE_CALC    = 3'd4;
    localparam MODE_SETUP   = 3'd5;

    // --------------------
    // CALC Parameters (Moved from below)
    // --------------------
    localparam CALC_WAIT_OP      = 3'd0;
    localparam CALC_OP_TRANSPOSE = 3'd1;
    localparam CALC_OP_ADD       = 3'd2;
    localparam CALC_OP_SCALAR    = 3'd3;
    localparam CALC_OP_MUL       = 3'd4;
    localparam CALC_OP_CONV      = 3'd5;

    // CALC flow state machine (after op selected)
    localparam CALC_FLOW_IDLE              = 5'd0;
    localparam CALC_FLOW_SEND_INFO         = 5'd1;
    localparam CALC_FLOW_GET_DIMS          = 5'd2; // Replaces WAIT1/2 INPUT/CONFIRM
    // localparam CALC_FLOW_WAIT1_INPUT       = 5'd2;
    // localparam CALC_FLOW_WAIT1_CONFIRM     = 5'd3;
    // localparam CALC_FLOW_WAIT2_INPUT       = 5'd4;
    // localparam CALC_FLOW_WAIT2_CONFIRM     = 5'd5;
    localparam CALC_FLOW_PREP              = 5'd6;
    localparam CALC_FLOW_LIST_ARM          = 5'd7;
    localparam CALC_FLOW_LIST_WAIT         = 5'd8;
    localparam CALC_FLOW_GET_ID            = 5'd9; // Replaces SEL INPUT/CONFIRM
    // localparam CALC_FLOW_SEL_INPUT         = 5'd9;
    // localparam CALC_FLOW_SEL_CONFIRM       = 5'd10;
    localparam CALC_FLOW_SHOW_ONE_ARM      = 5'd11;
    localparam CALC_FLOW_SHOW_ONE_WAIT     = 5'd12;
    localparam CALC_FLOW_SCALAR_WAIT       = 5'd13;
    localparam CALC_FLOW_COMPUTE_LATCH     = 5'd14;
    localparam CALC_FLOW_RESULT_SEND_ARM   = 5'd15;
    localparam CALC_FLOW_RESULT_SEND_WAIT  = 5'd16;
    localparam CALC_FLOW_DONE_WAIT_CONFIRM = 5'd17;
    localparam CALC_FLOW_CONV_RESET        = 5'd18;
    localparam CALC_FLOW_CONV_INPUT        = 5'd19;
    localparam CALC_FLOW_CONV_CONFIRM      = 5'd20;
    localparam CALC_FLOW_LIST_SEND         = 5'd21;

    // Matrix packing helpers
    localparam integer MATRIX_WIDTH = 25 * 8;
    localparam integer CONV_RESULT_WIDTH = 80 * 8;
    localparam integer MATRIX_DEPTH = 5;
    localparam integer TOTAL_WIDTH  = MATRIX_WIDTH * MATRIX_DEPTH;

    // --------------------
    // Basic mode handling
    // --------------------
    reg [2:0]  mode_state;
    wire        error_active;
    wire        blink_bit;
    wire        btn_pulse;
    wire        error_pulse;
    wire        mode_sw_valid_onehot;

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

    // 璇风‘淇濅綘鏈� debouncer.v
    debouncer #(
        .CLK_FREQ(CLK_FREQ_HZ)
    ) u_db (
        .clk(clk),
        .rst_n(rst_n),
        .key_in(btn),
        .key_flag(btn_pulse)
    );

    // 璇风‘淇濅綘鏈� error_blink.v
    error_blink #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BLINK_HZ(BLINK_HZ)
    ) u_error (
        .clk(clk),
        .rst_n(rst_n),
        .btn_pulse(btn_pulse),
        .mode_sw(mode_sw),
        .mode_state(mode_state),
        .error_pulse(error_pulse),
        .error_active(error_active),
        .blink_bit(blink_bit)
    );

    assign mode_sw_valid_onehot = (mode_sw == 5'b00001) ||
                                 (mode_sw == 5'b00010) ||
                                 (mode_sw == 5'b00100) ||
                                 (mode_sw == 5'b01000) ||
                                 (mode_sw == 5'b10000);

    // --------------------
    // Random Generator & Command Detection
    // --------------------
    wire [25*8-1:0] rand_data_flat;
    reg [7:0]       rand_max_val;
    reg             rand_gen_enable;
    
    random u_random (
        .clk(clk),
        .rst(~rst_n),
        .genEnable(rand_gen_enable),
        .max_val(rand_max_val),
        .readData(rand_data_flat)
    );

    reg [47:0] uart_shift_reg;
    reg        rand_detected;
    reg        matrix_detected;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_shift_reg <= 48'd0;
            rand_detected  <= 1'b0;
            matrix_detected <= 1'b0;
        end else begin
            if (rx_done) begin
                uart_shift_reg <= {uart_shift_reg[39:0], rx_data};
                // Check if the NEW shift register content (formed by old[23:0] + rx_data) is "rand"
                if ({uart_shift_reg[23:0], rx_data} == "rand") begin
                    rand_detected <= 1'b1;
                end else begin
                    rand_detected <= 1'b0;
                end

                // Check for "matrix"
                if ({uart_shift_reg[39:0], rx_data} == "matrix") begin
                    matrix_detected <= 1'b1;
                end else begin
                    matrix_detected <= 1'b0;
                end
            end else begin
                rand_detected <= 1'b0;
                matrix_detected <= 1'b0;
            end
        end
    end

    // --------------------
    // SETUP Mode Logic
    // --------------------
    localparam SETUP_IDLE = 2'd0;
    localparam SETUP_WAIT_CONFIRM = 2'd1;
    localparam SETUP_ADJUST = 2'd2;

    reg [1:0] setup_state;
    reg [2:0] user_max_limit;
    reg       setup_error_pulse;

    // Helper to extract scalar from switches (same as CALC mode)
    wire [3:0] setup_scalar_val;
    assign setup_scalar_val = {mode_sw[0], mode_sw[1], mode_sw[2], mode_sw[3]};

    // Use storage_rst (POR) instead of rst_n for user_max_limit
    // so it survives the user reset (which returns to DEFAULT mode).
    always @(posedge clk or posedge storage_rst) begin
        if (storage_rst) begin
            setup_state <= SETUP_IDLE;
            user_max_limit <= 3'd3; // Default to 3
            setup_error_pulse <= 1'b0;
        end else begin
            setup_error_pulse <= 1'b0; // Pulse default low

            // If global reset (rst_n) is asserted, we should reset the state machine
            // but NOT the user_max_limit.
            if (!rst_n) begin
                setup_state <= SETUP_IDLE;
            end else begin
                if (mode_state != MODE_SETUP) begin
                    setup_state <= SETUP_IDLE;
                end else begin
                    case (setup_state)
                        SETUP_IDLE: begin
                            if (matrix_detected) begin
                                setup_state <= SETUP_WAIT_CONFIRM;
                            end
                        end
                        SETUP_WAIT_CONFIRM: begin
                            if (btn_pulse) begin
                                setup_state <= SETUP_ADJUST;
                            end
                        end
                        SETUP_ADJUST: begin
                            if (btn_pulse) begin
                                // Validate input
                                // Max storage range is 5 (physical limit)
                                // Cannot be 0
                                if (setup_scalar_val > 0 && setup_scalar_val <= 5) begin
                                    user_max_limit <= setup_scalar_val[2:0];
                                    setup_state <= SETUP_IDLE;
                                end else begin
                                    setup_error_pulse <= 1'b1;
                                    // Stay in ADJUST
                                end
                            end
                        end
                    endcase
                end
            end
        end
    end

    // Allow CALC mode to return to DEFAULT by user confirmation (no global reset).
    reg calc_exit_to_default;

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
            end else if (mode_state == MODE_CALC && calc_exit_to_default) begin
                mode_state <= MODE_DEFAULT;
            end else begin
                mode_state <= mode_state; // Stay in mode until explicit exit/reset
            end
        end
    end

    // 璇风‘淇濅綘鏈� led_display.v
    wire alert_active;
    wire alert_blink_bit;
    wire [7:0] led_out_wire;
    led_display u_led (
        .mode_state(mode_state),
        .error_active(error_active),
        .blink_bit(blink_bit),
        .alert_active(alert_active),
        .alert_blink_bit(alert_blink_bit),
        .mode_sw(mode_sw),
        .mode_led(led_out_wire)
    );
    
    // Debug: show conv_input_cnt on LEDs in CALC mode
    assign mode_led = (mode_state == MODE_CALC && calc_state == CALC_OP_CONV) ? {4'b0, conv_input_cnt} : led_out_wire;

    wire       calc_countdown_en;
    wire [4:0] calc_countdown_sec;
    reg        calc_force_mode_pulse;
    
    wire setup_scalar_disp_en;
    assign setup_scalar_disp_en = (mode_state == MODE_SETUP) && (setup_state == SETUP_ADJUST);

    wire calc_cycle_disp_en;
    assign calc_cycle_disp_en = (calc_state == CALC_OP_CONV) && (calc_flow >= CALC_FLOW_RESULT_SEND_ARM);

    seven_seg_display u_seg (
        .clk(clk),
        .rst_n(rst_n),
        .mode_state(mode_state),
        .force_mode_pulse(calc_force_mode_pulse),
        .calc_op_pulse(calc_op_disp_pulse),
        .calc_op_char(calc_op_disp_char),
        .calc_op_hold(calc_op_hold),
        .calc_op_hold_char(setup_scalar_disp_en ? "L" : calc_op_hold_char),
        .scalar_disp_en(calc_scalar_disp_en | setup_scalar_disp_en),
        .scalar_val(setup_scalar_disp_en ? setup_scalar_val : calc_scalar_val),
        .countdown_en(calc_countdown_en),
        .countdown_sec(calc_countdown_sec),
        .cycle_disp_en(calc_cycle_disp_en),
        .cycle_count(conv_cycles),
        .seg(seg),
        .an(an)
    );

    // --------------------
    // UART RX for SHOW input
    // --------------------

    // 璇风‘淇濅綘鏈� UartRx.v
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
    // UART RX for STORE input
    // --------------------
    wire [7:0]   store_rx_m;
    wire [7:0]   store_rx_n;
    wire [199:0] store_rx_data;
    wire         store_rx_done;
    wire         store_rx_error;
    reg          store_rx_start;

    // STORE mode FSM for RX and Echo
    localparam STORE_IDLE = 2'd0;
    localparam STORE_RX   = 2'd1;
    localparam STORE_TX   = 2'd2;
    localparam STORE_WAIT = 2'd3;
    reg [1:0] store_state_fsm;
    reg       store_send_pulse;
    reg       store_seen_matrix_busy;

    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            store_state_fsm <= STORE_IDLE;
            store_rx_start <= 1'b0;
            store_send_pulse <= 1'b0;
            store_seen_matrix_busy <= 1'b0;
        end else begin
            store_rx_start <= 1'b0;
            store_send_pulse <= 1'b0;
            
            if (mode_state != MODE_STORE) begin
                store_state_fsm <= STORE_IDLE;
                store_seen_matrix_busy <= 1'b0;
            end else begin
                case (store_state_fsm)
                    STORE_IDLE: begin
                        // Start RX immediately upon entry
                        store_rx_start <= 1'b1;
                        store_state_fsm <= STORE_RX;
                    end
                    STORE_RX: begin
                        if (store_rx_done) begin
                            if (!store_rx_error) begin
                                // Received valid matrix. Storage write happens in parallel (see storage block).
                                // Now echo it back using MatrixUartTx.
                                store_state_fsm <= STORE_TX;
                            end else begin
                                // Error, retry RX
                                store_rx_start <= 1'b1;
                            end
                        end
                    end
                    STORE_TX: begin
                        // Wait for shared UART to be free
                        if (!shared_matrix_busy && !mode_uart_busy) begin
                            store_send_pulse <= 1'b1;
                            store_seen_matrix_busy <= 1'b0;
                            store_state_fsm <= STORE_WAIT;
                        end
                    end
                    STORE_WAIT: begin
                        if (shared_matrix_busy) begin
                            store_seen_matrix_busy <= 1'b1;
                        end
                        if (store_seen_matrix_busy && !shared_matrix_busy) begin
                            // Done sending, ready for next input
                            store_rx_start <= 1'b1;
                            store_state_fsm <= STORE_RX;
                        end
                    end
                    default: begin
                        store_state_fsm <= STORE_IDLE;
                        store_seen_matrix_busy <= 1'b0;
                    end
                endcase
            end
        end
    end

    MatrixUartRx u_store_rx (
        .clk(clk),
        .uartRxRstN(rst_n),
        .rx(uart_rx),
        .rxStart(store_rx_start),
        .lowerLimit(8'd0),
        .upperLimit(8'd9),
        .m(store_rx_m),
        .n(store_rx_n),
        .matrixData(store_rx_data),
        .rxDone(store_rx_done),
        .rxError(store_rx_error)
    );

    // --------------------
    // Matrix storage
    // --------------------
    reg               storage_we;
    reg [7:0]         storage_dimX;
    reg [7:0]         storage_dimY;
    reg [199:0]       storage_wdata;
    wire [MATRIX_WIDTH-1:0] storage_rdata;
    wire [2:0]        storage_count;

    // SHOW controller signals needed for matrixIO
    reg [7:0] req_m, req_n;

    // CALC controller signals needed for matrixIO
    reg [7:0] calc_req_m, calc_req_n;

    // SHOW matrix inventory info (before user inputs dimensions)
    reg        show_info_req;
    reg        show_info_start;
    reg        show_info_seen_busy;
    wire       show_info_uart_busy;
    wire       show_info_uart_tx;

    // CALC matrix inventory info (same format as SHOW)
    reg        calc_info_req;
    reg        calc_info_start;
    reg        calc_info_seen_busy;
    wire       calc_info_uart_tx;

    // Forward declarations for GEN signals used in storage block
    reg       gen_write_req;
    reg [7:0] gen_write_dimX;
    reg [7:0] gen_write_dimY;
    reg [199:0] gen_write_wdata;
    reg [7:0] gen_m, gen_n; 
    
    wire [74:0] matrix_list_info;

    wire [2:0] storage_read_idx;
    assign storage_read_idx = (mode_state == MODE_SHOW) ? show_cursor :
                              (mode_state == MODE_CALC) ? calc_sel_cursor : 3'd0;

    wire [3*MATRIX_WIDTH-1:0] storage_rdata_all;
    assign storage_rdata = (storage_read_idx == 3'd0) ? storage_rdata_all[199:0] :
                           (storage_read_idx == 3'd1) ? storage_rdata_all[399:200] :
                           (storage_read_idx == 3'd2) ? storage_rdata_all[599:400] : {MATRIX_WIDTH{1'b0}};

    // 璇风‘淇濅綘鏈� matrixIO.v
    matrixIO u_matrix_store (
        .clk(clk),
        .rst(storage_rst),
        .writeEnable(storage_we),
        .dimX(storage_dimX),
        .dimY(storage_dimY),
        .user_max_limit(user_max_limit),
        // .readIdx(storage_read_idx), // Removed
        .writeData(storage_wdata),
        .readData(storage_rdata_all),
        .fillState(storage_count),
        .matrixListInfo(matrix_list_info)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            storage_we   <= 1'b0;
            storage_dimX <= 8'd1;
            storage_dimY <= 8'd1;
            storage_wdata<= {MATRIX_WIDTH{1'b0}};
        end else begin
            storage_we <= 1'b0;

            // During storage reset window, don't write.
            if (!storage_rst) begin
                // GEN write has priority; otherwise track dims for SHOW/GEN reads
                if (gen_write_req) begin
                    storage_dimX  <= gen_write_dimX;
                    storage_dimY  <= gen_write_dimY;
                    storage_wdata <= gen_write_wdata;
                    storage_we    <= 1'b1;
                end else if (mode_state == MODE_STORE && store_rx_done && !store_rx_error) begin
                    storage_dimX  <= store_rx_m;
                    storage_dimY  <= store_rx_n;
                    storage_wdata <= store_rx_data;
                    storage_we    <= 1'b1;
                end else if (mode_state == MODE_SHOW) begin
                    storage_dimX <= req_m;
                    storage_dimY <= req_n;
                end else if (mode_state == MODE_CALC) begin
                    storage_dimX <= calc_req_m;
                    storage_dimY <= calc_req_n;
                end else if (mode_state == MODE_GEN) begin
                    storage_dimX <= gen_m;
                    storage_dimY <= gen_n;
                end
            end
        end
    end

    // --------------------
    // SHOW controller (Fixed Logic)
    // --------------------
    localparam SHOW_IDLE        = 3'd0;
    localparam SHOW_ENTRY_WAIT1 = 3'd1;
    localparam SHOW_SEND_INFO   = 3'd7;
    localparam SHOW_WAIT_M      = 3'd2;
    localparam SHOW_WAIT_N      = 3'd3;
    localparam SHOW_PREP        = 3'd4;
    localparam SHOW_SEND_ARM    = 3'd5;
    localparam SHOW_SEND_WAIT   = 3'd6;

    localparam PROMPT_WAIT1    = 3'd0;
    localparam PROMPT_WAIT2    = 3'd1;
    localparam PROMPT_WAIT3    = 3'd2;
    localparam PROMPT_DISPLAY  = 3'd3;
    localparam PROMPT_GENERATE = 3'd4;
    localparam PROMPT_SHOW     = 3'd5;

    reg [2:0] show_state;
    // reg [2:0] show_cursor; // Moved to top
    reg       show_send_pulse;
    reg       show_seen_matrix_busy;
    reg       prompt_start;
    reg [2:0] prompt_sel;
    reg       prompt_req;
    reg [2:0] prompt_req_sel;
    
    // Timer to wait for storage lookup
    reg [1:0] prep_timer;

    wire [7:0] rx_digit;
    wire       rx_digit_ok;
    wire       rx_is_ignore;
    wire       rx_digit_valid_any;

    // Detect UART busyness to avoid collision 

    assign rx_digit     = decode_digit(rx_data);
    assign rx_digit_ok  = (rx_digit >= 8'd1) && (rx_digit <= 8'd5);
    assign rx_digit_valid_any = (rx_data >= 8'h30) && (rx_data <= 8'h39);
    wire [7:0] rx_digit_val_any;
    assign rx_digit_val_any = rx_data - 8'h30;
    // Ignore CR (0D), LF (0A), Space (20)
    assign rx_is_ignore = (rx_data == 8'h0D) || (rx_data == 8'h0A) || (rx_data == 8'h20);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            show_state      <= SHOW_IDLE;
            req_m           <= 8'd1;
            req_n           <= 8'd1;
            show_cursor     <= 3'd0;
            show_send_pulse <= 1'b0;
            show_seen_matrix_busy <= 1'b0;
            prompt_start    <= 1'b0;
            prompt_sel      <= PROMPT_WAIT1;
            prompt_req      <= 1'b0;
            prompt_req_sel  <= PROMPT_WAIT1;
            prep_timer      <= 2'd0;
            show_info_req   <= 1'b0;
            show_info_start <= 1'b0;
            show_info_seen_busy <= 1'b0;
        end else begin
            show_send_pulse <= 1'b0;
            prompt_start    <= 1'b0;
            show_info_start <= 1'b0;

            // If we leave SHOW mode, cancel pending prompts
            if (mode_state != MODE_SHOW) begin
                prompt_req <= 1'b0;
                show_info_req <= 1'b0;
                show_info_seen_busy <= 1'b0;
                show_seen_matrix_busy <= 1'b0;
            end

            case (show_state)
                SHOW_IDLE: begin
                    show_cursor <= 3'd0;
                    prep_timer  <= 2'd0;
                    // 銆愬叧閿慨鏀广�戝繀椤荤瓑寰� mode_uart_busy 缁撴潫锛屽惁鍒� SHOW 娑堟伅浼氳瑕嗙洊
                    if (mode_state == MODE_SHOW && !mode_uart_busy) begin
                        // Entry point: Request "show" then "wait1"
                        prompt_req     <= 1'b1;
                        prompt_req_sel <= PROMPT_SHOW;
                        show_state     <= SHOW_ENTRY_WAIT1;
                    end
                end

                SHOW_ENTRY_WAIT1: begin
                    show_cursor <= 3'd0;
                    if (mode_state != MODE_SHOW) begin
                        show_state <= SHOW_IDLE;
                    end else if (!prompt_req && !prompt_uart_busy) begin
                        // After "show" is sent, print inventory info first
                        show_info_req <= 1'b1;
                        show_info_seen_busy <= 1'b0;
                        show_state    <= SHOW_SEND_INFO;
                    end
                end

                SHOW_SEND_INFO: begin
                    show_cursor <= 3'd0;
                    if (mode_state != MODE_SHOW) begin
                        show_state <= SHOW_IDLE;
                    end else begin
                        if (show_info_uart_busy) begin
                            show_info_seen_busy <= 1'b1;
                        end

                        if (show_info_seen_busy && !show_info_uart_busy && !show_info_req) begin
                        // Inventory info done -> now prompt for dimensions
                        prompt_req     <= 1'b1;
                        prompt_req_sel <= PROMPT_WAIT1;
                        show_state     <= SHOW_WAIT_M;
                        end
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
                        show_seen_matrix_busy <= 1'b0;
                        show_state      <= SHOW_SEND_WAIT;
                    end
                end

                SHOW_SEND_WAIT: begin
                    if (mode_state != MODE_SHOW) begin
                        show_state <= SHOW_IDLE;
                    end else begin
                        // MatrixUartTx asserts busy one clock after sendOne.
                        // Don't treat a send as finished until we've observed busy high at least once.
                        if (show_matrix_busy) begin
                            show_seen_matrix_busy <= 1'b1;
                        end

                        if (show_seen_matrix_busy && !show_matrix_busy) begin
                            // Matrix transmission finished
                            show_cursor <= show_cursor + 1'b1;
                            show_state  <= SHOW_SEND_ARM;
                        end
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

            // Dispatch SHOW inventory info when UART is clear
            if (!show_tx_busy && !mode_uart_busy && show_info_req && mode_state == MODE_SHOW) begin
                show_info_start <= 1'b1;
                show_info_req   <= 1'b0;
            end
        end
    end

    // --------------------
    // Output Multiplexing & TX modules
    // --------------------

    wire [199:0] show_matrix_slice;
    assign show_matrix_slice = storage_rdata;

    wire prompt_uart_tx;
    wire matrix_uart_tx;
    // wire show_info_uart_tx; // Removed duplicate
    // wire calc_info_uart_tx; // Removed duplicate
    
    // Explicit declarations for shared signals
    wire calc_prompt_uart_tx;
    wire gen_prompt_uart_tx;
    wire calc_matrix_uart_tx;
    wire gen_matrix_uart_tx;
    // wire calc_matrix_busy_wire; // Removed (using calc_matrix_tx_busy directly)
    // wire gen_matrix_busy_wire;  // Removed (declared at top)

    // Use MatrixUartTx busy directly (no registered lag).
    assign show_tx_busy = prompt_uart_busy || show_matrix_busy || show_info_uart_busy;

    // --- Shared Prompt TX ---
    wire shared_prompt_start;
    wire [2:0] shared_prompt_sel;
    wire shared_prompt_busy;
    wire shared_prompt_tx;

    assign shared_prompt_start = (mode_state == MODE_SHOW) ? prompt_start :
                                 (mode_state == MODE_CALC) ? calc_prompt_start :
                                 (mode_state == MODE_GEN)  ? gen_prompt_start : 1'b0;
    
    assign shared_prompt_sel   = (mode_state == MODE_SHOW) ? prompt_sel :
                                 (mode_state == MODE_CALC) ? calc_prompt_sel :
                                 (mode_state == MODE_GEN)  ? gen_prompt_sel : 3'd0;

    assign prompt_uart_busy      = shared_prompt_busy;
    assign calc_prompt_uart_busy = shared_prompt_busy;
    assign gen_prompt_uart_busy  = shared_prompt_busy;
    assign prompt_uart_tx        = shared_prompt_tx;
    assign calc_prompt_uart_tx   = shared_prompt_tx;
    assign gen_prompt_uart_tx    = shared_prompt_tx;

    ShowUartTx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(115200)
    ) u_shared_prompt (
        .clk(clk),
        .uartTxRstN(rst_n),
        .sendOne(1'b0),
        .promptStart(shared_prompt_start),
        .promptSel(shared_prompt_sel),
        .uartTx(shared_prompt_tx),
        .busy(shared_prompt_busy)
    );

    // --- Shared Info TX ---
    wire shared_info_start;
    wire shared_info_busy;
    wire shared_info_tx;

    assign shared_info_start = (mode_state == MODE_SHOW) ? show_info_start :
                               (mode_state == MODE_CALC) ? calc_info_start : 1'b0;
    
    assign show_info_uart_busy = shared_info_busy;
    assign calc_info_uart_busy = shared_info_busy;
    assign show_info_uart_tx   = shared_info_tx;
    assign calc_info_uart_tx   = shared_info_tx;

    InfoUartTx u_shared_info (
        .clk(clk),
        .uartTxRstN(rst_n),
        .sendOne(shared_info_start),
        .matrixListInfo(matrix_list_info),
        .uartTx(shared_info_tx),
        .busy(shared_info_busy)
    );

    // --- Shared Matrix TX ---
    wire shared_matrix_send;
    wire [199:0] shared_matrix_data;
    wire [7:0] shared_matrix_m;
    wire [7:0] shared_matrix_n;
    wire [7:0] shared_matrix_id;
    // wire shared_matrix_busy; // Moved to forward declarations
    wire shared_matrix_tx;

    assign shared_matrix_send = (mode_state == MODE_SHOW) ? show_send_pulse :
                                (mode_state == MODE_CALC) ? calc_send_pulse :
                                (mode_state == MODE_GEN)  ? gen_send_pulse :
                                (mode_state == MODE_STORE)? store_send_pulse : 1'b0;

    assign shared_matrix_data = (mode_state == MODE_SHOW) ? show_matrix_slice :
                                (mode_state == MODE_CALC) ? calc_matrix_slice :
                                (mode_state == MODE_GEN)  ? gen_matrix_latched :
                                (mode_state == MODE_STORE)? store_rx_data : {MATRIX_WIDTH{1'b0}};
    
    assign shared_matrix_m    = (mode_state == MODE_SHOW) ? req_m :
                                (mode_state == MODE_CALC) ? calc_req_m :
                                (mode_state == MODE_GEN)  ? gen_m_latched :
                                (mode_state == MODE_STORE)? store_rx_m : 8'd1;

    assign shared_matrix_n    = (mode_state == MODE_SHOW) ? req_n :
                                (mode_state == MODE_CALC) ? calc_req_n :
                                (mode_state == MODE_GEN)  ? gen_n_latched :
                                (mode_state == MODE_STORE)? store_rx_n : 8'd1;

    assign shared_matrix_id   = (mode_state == MODE_SHOW) ? ({5'b0, show_cursor} + 8'd1) :
                                (mode_state == MODE_CALC) ? ({5'b0, calc_sel_cursor} + 8'd1) :
                                (mode_state == MODE_GEN)  ? gen_id_latched :
                                (mode_state == MODE_STORE)? 8'd0 : 8'd1; // ID 0 for echo

    assign show_matrix_busy      = shared_matrix_busy;
    assign calc_matrix_tx_busy   = shared_matrix_busy;
    assign gen_matrix_busy_wire  = shared_matrix_busy;
    assign matrix_uart_tx        = shared_matrix_tx;
    assign calc_matrix_uart_tx   = shared_matrix_tx;
    assign gen_matrix_uart_tx    = shared_matrix_tx;

    wire shared_matrix_ifID;
    assign shared_matrix_ifID = (mode_state == MODE_STORE) ? 1'b0 : 1'b1;

    MatrixUartTx u_shared_matrix (
        .clk(clk),
        .uartTxRstN(rst_n),
        .sendOne(shared_matrix_send),
        .matrixData(shared_matrix_data),
        .m(shared_matrix_m),
        .n(shared_matrix_n),
        .id(shared_matrix_id),
        .ifID(shared_matrix_ifID),
        .ifNM(1'b1),
        .uartTx(shared_matrix_tx),
        .busy(shared_matrix_busy)
    );

    wire mode_uart_tx;

    // 璇风‘淇濅綘鏈� ModeUartNotifier.v
    ModeUartNotifier #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ)
    ) u_mode_uart (
        .clk(clk),
        .rst_n(rst_n),
        .mode_state(mode_state),
        .uart_tx(mode_uart_tx),
        .busy(mode_uart_busy)
    );

    // --------------------
    // CALC controller (operation type selection only; actual math TBD)
    // --------------------
    // Parameters moved to top of file for visibility

    // Timer to wait for storage lookup after setting dims
    reg [1:0] calc_prep_timer;

    // Operand bookkeeping
    reg       calc_need_second;
    reg       calc_is_scalar;
    reg       calc_operand_idx; // 0 -> first matrix, 1 -> second matrix

    // Input staging for confirm-key workflow
    reg       calc_m_ready;
    reg [7:0] calc_m_pending;
    reg       calc_n_ready;
    reg [7:0] calc_n_pending;
    reg       calc_id_ready;
    reg [7:0] calc_id_pending;
    
    // Convolution input counter

    // Matrix listing/selection cursors
    reg [2:0] calc_list_cursor;
    // reg [2:0] calc_sel_cursor; // Moved to top
    reg       calc_seen_matrix_busy;

    // Prompt + matrix TX for CALC
    // reg       calc_prompt_start; // Moved to top
    // reg [2:0] calc_prompt_sel;   // Moved to top
    reg       calc_prompt_req;
    reg [2:0] calc_prompt_req_sel;

    // reg       calc_send_pulse; // Moved to top
    // wire      calc_matrix_tx_busy; // Moved to top
    reg [31:0] calc_matrix_idle_cnt;

    // Two-operand dimension bookkeeping (for compatibility validation)
    reg [7:0] calc_op1_m;
    reg [7:0] calc_op1_n;
    reg [7:0] calc_op2_m;
    reg [7:0] calc_op2_n;

    // Operand matrix latching (tight packed, m*n elements)
    reg [199:0] calc_op1_matrix_tight;
    reg [199:0] calc_op2_matrix_tight;

    reg       calc_wait_rand;
    reg       calc_wait_rand_scalar;

    // Result latching for UART output
    reg [CONV_RESULT_WIDTH-1:0] calc_result_matrix_tight;
    reg [7:0]   calc_result_m;
    reg [7:0]   calc_result_n;
    reg         calc_result_send_pulse;
    // wire        calc_result_tx_busy; // Moved to top
    reg         calc_seen_result_busy;
    reg [31:0]  calc_result_idle_cnt;

    // Countdown + alert blink for invalid dimension combinations
    reg        calc_countdown_en_r;
    reg [4:0]  calc_countdown_sec_r;
    reg [31:0] calc_countdown_cnt_r;
    reg [31:0] alert_blink_cnt;
    reg        alert_blink_bit_r;

    assign calc_countdown_en  = calc_countdown_en_r;
    assign calc_countdown_sec = calc_countdown_sec_r;
    assign alert_active       = (mode_state == MODE_CALC) && calc_countdown_en_r;
    assign alert_blink_bit    = alert_blink_bit_r;

    localparam integer ALERT_BLINK_HALF_CYCLES = CLK_FREQ_HZ/(BLINK_HZ*2);
    localparam integer ONE_SEC_CYCLES          = CLK_FREQ_HZ;

    function automatic calc_dims_ok;
        input [2:0] op;
        input [7:0] m1;
        input [7:0] n1;
        input [7:0] m2;
        input [7:0] n2;
        begin
            case (op)
                CALC_OP_ADD: calc_dims_ok = (m1 == m2) && (n1 == n2);
                CALC_OP_MUL: calc_dims_ok = (n1 == m2);
                CALC_OP_CONV: calc_dims_ok = (m2 >= 8'd1) && (n2 >= 8'd1) &&
                                             (m2 <= 8'd3) && (n2 <= 8'd3) &&
                                             (m1 >= m2) && (n1 >= n2);
                default: calc_dims_ok = 1'b1;
            endcase
        end
    endfunction

    // Scalar input via switches
    reg        rand_scalar_active;
    reg [3:0]  rand_scalar_stored;
    // Physical switch order is reversed for scalar entry: bit-reverse the 4 LSBs.
    // If random scalar is active, use stored random value.
    assign calc_scalar_val = rand_scalar_active ? rand_scalar_stored : {mode_sw[0], mode_sw[1], mode_sw[2], mode_sw[3]};

    // Fake compute word TX ("calc\n")
    reg       calc_word_req;
    reg       calc_word_active;
    reg [2:0] calc_word_idx;
    reg       calc_word_txStart;
    reg [7:0] calc_word_txData;
    wire      calc_word_uart_tx;

    function automatic [7:0] calc_word_char;
        input [2:0] idx;
        begin
            case (idx)
                3'd0: calc_word_char = "c";
                3'd1: calc_word_char = "a";
                3'd2: calc_word_char = "l";
                3'd3: calc_word_char = "c";
                default: calc_word_char = "\n";
            endcase
        end
    endfunction

    UartTx #(
        .CLK_FREQ(CLK_FREQ_HZ),
        .BAUD_RATE(115200)
    ) u_calc_word_uart (
        .clk(clk),
        .rstN(rst_n),
        .txStart(calc_word_txStart),
        .txData(calc_word_txData),
        .tx(calc_word_uart_tx),
        .txBusy(calc_word_txBusy)
    );

    // Persistent selected op letter for hold display
    reg [7:0] calc_selected_char;

    // UART TX (single byte) for op letter
    reg       calc_op_tx_start;
    reg [7:0] calc_op_tx_data;
    wire      calc_op_uart_tx;
    reg       calc_op_tx_pending;
    reg [7:0] calc_op_tx_pending_char;

    assign calc_op_hold      = (mode_state == MODE_CALC) && (calc_state != CALC_WAIT_OP);
    assign calc_op_hold_char = calc_selected_char;

    function automatic [2:0] sw_to_calc_op;
        input [4:0] v;
        begin
            case (v)
                5'b00001: sw_to_calc_op = CALC_OP_TRANSPOSE;
                5'b00010: sw_to_calc_op = CALC_OP_ADD;
                5'b00100: sw_to_calc_op = CALC_OP_SCALAR;
                5'b01000: sw_to_calc_op = CALC_OP_MUL;
                5'b10000: sw_to_calc_op = CALC_OP_CONV;
                default:  sw_to_calc_op = CALC_WAIT_OP;
            endcase
        end
    endfunction

    function automatic [7:0] calc_op_to_char;
        input [2:0] op;
        begin
            case (op)
                CALC_OP_TRANSPOSE: calc_op_to_char = "T";
                CALC_OP_ADD:       calc_op_to_char = "A";
                CALC_OP_SCALAR:    calc_op_to_char = "B";
                CALC_OP_MUL:       calc_op_to_char = "C";
                CALC_OP_CONV:      calc_op_to_char = "J";
                default:           calc_op_to_char = 8'h00;
            endcase
        end
    endfunction

    // Single-byte UART TX instance for CALC op selection
    UartTx #(
        .CLK_FREQ(CLK_FREQ_HZ),
        .BAUD_RATE(115200)
    ) u_calc_op_uart (
        .clk(clk),
        .rstN(rst_n),
        .txStart(calc_op_tx_start),
        .txData(calc_op_tx_data),
        .tx(calc_op_uart_tx),
        .txBusy(calc_op_tx_busy)
    );

    // CALC prompt TX (reuse existing prompt strings)
    // wire calc_prompt_uart_tx; // Handled by shared instance

    // ShowUartTx #(
    //     .CLK_FREQ_HZ(CLK_FREQ_HZ),
    //     .BAUD_RATE(115200)
    // ) u_calc_prompt (
    //     .clk(clk),
    //     .uartTxRstN(rst_n),
    //     .sendOne(1'b0),
    //     .promptStart(calc_prompt_start),
    //     .promptSel(calc_prompt_sel),
    //     .uartTx(calc_prompt_uart_tx),
    //     .busy(calc_prompt_uart_busy)
    // );

    // CALC matrix TX
    // wire [199:0] calc_matrix_slice; // Moved to top
    assign calc_matrix_slice = storage_rdata;

    // wire calc_matrix_uart_tx; // Handled by shared instance
    // wire calc_matrix_busy_wire; // Handled by shared instance

    // MatrixUartTx u_calc_matrix (
    //     .clk(clk),
    //     .uartTxRstN(rst_n),
    //     .sendOne(calc_send_pulse),
    //     .matrixData(calc_matrix_slice),
    //     .m(calc_req_m),
    //     .n(calc_req_n),
    //     .id({5'b0, calc_sel_cursor} + 8'd1),
    //     .ifID(1'b1),
    //     .ifNM(1'b1),
    //     .uartTx(calc_matrix_uart_tx),
    //     .busy(calc_matrix_busy_wire)
    // );

    // assign calc_matrix_tx_busy = calc_matrix_busy_wire;

    // CALC RX signals
    reg        calc_nm_start;

    reg        calc_id_start;

    NMUartRx u_calc_nm_rx (
        .clk(clk),
        .uartRxRstN(rst_n),
        .rx(uart_rx),
        .rxStart(calc_nm_start),
        .matrixListInfo({75{1'b1}}), // Always allow parsing, check existence later
        .m(calc_nm_m),
        .n(calc_nm_n),
        .rxDone(calc_nm_done),
        .rxError(calc_nm_error)
    );

    IdUartRx u_calc_id_rx (
        .clk(clk),
        .uartRxRstN(rst_n),
        .rx(uart_rx),
        .rxStart(calc_id_start),
        .m(calc_req_m),
        .n(calc_req_n),
        .matrixListInfo(matrix_list_info),
        .id(calc_id_val),
        .rxDone(calc_id_done),
        .rxError(calc_id_error)
    );



    // wire [199:0] calc_op1_padded;
    // wire [199:0] calc_op2_padded;
    // assign calc_op1_padded = tight_to_padded_5x5(calc_op1_matrix_tight, calc_op1_m[2:0], calc_op1_n[2:0]);
    // assign calc_op2_padded = tight_to_padded_5x5(calc_op2_matrix_tight, calc_op2_m[2:0], calc_op2_n[2:0]);

    // Since we are using 5x5 fixed storage in MatrixIO now (implied by previous changes to simplify),
    // we can just pass the data through. If MatrixIO still packs tightly, we need to unpack.
    // However, to save LUTs, we should assume fixed 5x5 layout or use a simpler unpacking if possible.
    // Given the previous optimization in MatrixIO was to remove the loop but keep the structure,
    // let's check MatrixIO again.
    // Wait, MatrixIO uses `mem[current_scale_idx][scalePtr][elemIdx]`.
    // And `readData` is `mem[...][...][eIdx]`.
    // It seems MatrixIO stores 25 elements regardless of M/N?
    // Yes, `MAX_ELEM = 25`.
    // So `storage_rdata` is always 200 bits (25 bytes).
    // If the user inputs a 2x2 matrix, how is it stored?
    // The `MatrixUartRx` likely packs it.
    // If we assume the data is ALREADY padded to 5x5 in storage (or we don't care about garbage in unused slots),
    // we can skip the complex re-shuffling functions.
    
    // Let's assume for optimization that we operate on the full 200 bits and mask outputs if needed,
    // OR that the storage format is already compatible.
    // Actually, `tight_to_padded` suggests storage is "tight" (row-major, no gaps).
    // But `MatrixIO` writes `writeData` directly to `mem`.
    // `MatrixUartRx` produces `matrixData`.
    
    // Let's look at `MatrixUartRx`.
    
    wire [199:0] calc_op1_padded;
    wire [199:0] calc_op2_padded;
    
    // Optimization: Direct assignment. 
    // If the calculation units can handle garbage in the padded areas (they usually respect m/n inputs),
    // then we don't need to reshuffle.
    // Most units take m/n as inputs.
    
    assign calc_op1_padded = calc_op1_matrix_tight;
    assign calc_op2_padded = calc_op2_matrix_tight;

    // For convolution kernel, we need the first 3x3.
    // If it's tight packed, 3x3 is just the first 9 bytes?
    // No, tight packing of 3x3 is: r0c0, r0c1, r0c2, r1c0...
    // Padded 5x5 is: r0c0..r0c4, r1c0..r1c4...
    // If `calc_op1_matrix_tight` is TIGHT, then for a 3x3 matrix, it IS the first 9 bytes.
    // So `padded_5x5_to_kernel3x3` is just taking the first 72 bits?
    // Wait, `padded_5x5_to_kernel3x3` takes a PADDED input.
    // If we change `calc_op1_padded` to be TIGHT, then `padded_5x5_to_kernel3x3` needs to change.
    
    // Let's redefine the kernel extraction to be simple:
    // If the input is 3x3, it occupies the first 9 bytes of the tight array.
    wire [71:0] conv_kernel;
    assign conv_kernel = calc_op1_padded[71:0]; 


    // Add
    wire [199:0] add_out_padded;
    wire add_valid;
    AddUnit u_add (
        .clk(clk),
        .reset(~rst_n),
        .m(calc_op1_m[2:0]),
        .n(calc_op1_n[2:0]),
        .matrixA_in(calc_op1_padded),
        .matrixB_in(calc_op2_padded),
        .matrix_out(add_out_padded),
        .valid(add_valid)
    );

    // Scalar multiply
    wire [199:0] scalar_out_padded;
    wire scalar_valid;
    ScalarMultiplyUnit u_scalar (
        .clk(clk),
        .reset(~rst_n),
        .m(calc_op1_m[2:0]),
        .n(calc_op1_n[2:0]),
        .scalarValue(calc_scalar_val),
        .matrix_in(calc_op1_padded),
        .matrix_out(scalar_out_padded),
        .valid(scalar_valid)
    );

    // Transpose
    wire [199:0] trans_out_padded;
    wire [2:0]   trans_m;
    wire [2:0]   trans_n;
    wire trans_valid;
    TransposeUnit u_transpose (
        .clk(clk),
        .reset(~rst_n),
        .m_in(calc_op1_m[2:0]),
        .n_in(calc_op1_n[2:0]),
        .matrix_in(calc_op1_padded),
        .m_out(trans_m),
        .n_out(trans_n),
        .matrix_out(trans_out_padded),
        .valid(trans_valid)
    );

    // Multiply
    wire [199:0] mul_out_padded;
    wire [2:0]   mul_m;
    wire [2:0]   mul_n;
    wire mul_valid;
    MatrixMultiplyUnit u_mul (
        .clk(clk),
        .reset(~rst_n),
        .a_m(calc_op1_m[2:0]),
        .a_n(calc_op1_n[2:0]),
        .b_m(calc_op2_m[2:0]),
        .b_n(calc_op2_n[2:0]),
        .matrixA_in(calc_op1_padded),
        .matrixB_in(calc_op2_padded),
        .c_m(mul_m),
        .c_n(mul_n),
        .matrix_out(mul_out_padded),
        .valid(mul_valid)
    );

    // Convolution
    // wire [71:0]  conv_kernel; // Removed duplicate declaration
    // assign conv_kernel = calc_op1_padded[71:0]; // Removed duplicate assignment
    wire [CONV_RESULT_WIDTH-1:0] conv_out_padded;
    wire [7:0]   conv_m;
    wire [7:0]   conv_n;
    wire conv_valid;
    reg calc_compute_start;

    ConvolutionUnit u_conv (
        .clk(clk),
        .reset(~rst_n),
        .start(calc_compute_start),
        .kernelMatrix(conv_kernel),
        .out_m(conv_m),
        .out_n(conv_n),
        .matrix_out(conv_out_padded),
        .valid(conv_valid),
        .cycleCount(conv_cycles)
    );

    // Selected result (padded 5x5) + dims
    reg [CONV_RESULT_WIDTH-1:0] calc_res_padded;
    reg [7:0]   calc_res_m;
    reg [7:0]   calc_res_n;
    reg         calc_res_valid;

    always @* begin
        calc_res_padded = {CONV_RESULT_WIDTH{1'b0}};
        calc_res_m      = 8'd0;
        calc_res_n      = 8'd0;
        calc_res_valid  = 1'b0;
        case (calc_state)
            CALC_OP_ADD: begin
                calc_res_padded = {{CONV_RESULT_WIDTH-200{1'b0}}, add_out_padded};
                calc_res_m      = {5'd0, calc_op1_m[2:0]};
                calc_res_n      = {5'd0, calc_op1_n[2:0]};
                calc_res_valid  = add_valid;
            end
            CALC_OP_SCALAR: begin
                calc_res_padded = {{CONV_RESULT_WIDTH-200{1'b0}}, scalar_out_padded};
                calc_res_m      = {5'd0, calc_op1_m[2:0]};
                calc_res_n      = {5'd0, calc_op1_n[2:0]};
                calc_res_valid  = scalar_valid;
            end
            CALC_OP_TRANSPOSE: begin
                calc_res_padded = {{CONV_RESULT_WIDTH-200{1'b0}}, trans_out_padded};
                calc_res_m      = {5'd0, trans_m};
                calc_res_n      = {5'd0, trans_n};
                calc_res_valid  = trans_valid;
            end
            CALC_OP_MUL: begin
                calc_res_padded = {{CONV_RESULT_WIDTH-200{1'b0}}, mul_out_padded};
                calc_res_m      = {5'd0, mul_m};
                calc_res_n      = {5'd0, mul_n};
                calc_res_valid  = mul_valid;
            end
            CALC_OP_CONV: begin
                calc_res_padded = conv_out_padded;
                calc_res_m      = conv_m;
                calc_res_n      = conv_n;
                calc_res_valid  = conv_valid;
            end
            default: begin
                calc_res_padded = {CONV_RESULT_WIDTH{1'b0}};
                calc_res_m      = 8'd0;
                calc_res_n      = 8'd0;
                calc_res_valid  = 1'b0;
            end
        endcase
    end

    // CALC result matrix TX
    wire calc_result_uart_tx;
    wire calc_result_busy_wire;
    MatrixUartTx #(
        .DATA_WIDTH(CONV_RESULT_WIDTH)
    ) u_calc_result_matrix (
        .clk(clk),
        .uartTxRstN(rst_n),
        .sendOne(calc_result_send_pulse),
        .matrixData(calc_result_matrix_tight),
        .m(calc_result_m),
        .n(calc_result_n),
        .id(8'd0),
        .ifID(1'b0),
        .ifNM(1'b1),
        .uartTx(calc_result_uart_tx),
        .busy(calc_result_busy_wire)
    );

    assign calc_result_tx_busy = calc_result_busy_wire;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            calc_state              <= CALC_WAIT_OP;
            calc_op_disp_pulse      <= 1'b0;
            calc_op_disp_char       <= 8'h00;
            calc_selected_char       <= 8'h00;
            calc_op_tx_start        <= 1'b0;
            calc_op_tx_data         <= 8'h00;
            calc_op_tx_pending      <= 1'b0;
            calc_op_tx_pending_char <= 8'h00;

            // CALC flow reset
            calc_flow          <= CALC_FLOW_IDLE;
            calc_req_m         <= 8'd1;
            calc_req_n         <= 8'd1;
            calc_m_ready       <= 1'b0;
            calc_n_ready       <= 1'b0;
            calc_id_ready      <= 1'b0;
            calc_m_pending     <= 8'd1;
            calc_n_pending     <= 8'd1;
            calc_id_pending    <= 8'd1;
            calc_list_cursor   <= 3'd0;
            calc_sel_cursor    <= 3'd0;
            calc_need_second   <= 1'b0;
            calc_is_scalar     <= 1'b0;
            calc_operand_idx   <= 1'b0;
            calc_prompt_start  <= 1'b0;
            calc_prompt_sel    <= PROMPT_WAIT1;
            calc_prompt_req    <= 1'b0;
            calc_prompt_req_sel<= PROMPT_WAIT1;
            calc_send_pulse    <= 1'b0;
            calc_info_req      <= 1'b0;
            calc_info_start    <= 1'b0;
            calc_info_seen_busy<= 1'b0;
            calc_scalar_disp_en<= 1'b0;
            calc_word_req      <= 1'b0;
            calc_word_active   <= 1'b0;
            calc_word_idx      <= 3'd0;
            calc_word_txStart  <= 1'b0;
            calc_word_txData   <= 8'h00;
            calc_prep_timer    <= 2'd0;

            calc_op1_m <= 8'd1;
            calc_op1_n <= 8'd1;
            calc_op2_m <= 8'd1;
            calc_op2_n <= 8'd1;

            calc_op1_matrix_tight <= {MATRIX_WIDTH{1'b0}};
            calc_op2_matrix_tight <= {MATRIX_WIDTH{1'b0}};
            calc_result_matrix_tight <= {MATRIX_WIDTH{1'b0}};
            calc_result_m <= 8'd1;
            calc_result_n <= 8'd1;
            calc_result_send_pulse <= 1'b0;
            calc_exit_to_default <= 1'b0;
            calc_seen_matrix_busy <= 1'b0;
            calc_seen_result_busy <= 1'b0;

            calc_countdown_en_r  <= 1'b0;
            calc_countdown_sec_r <= 5'd0;
            calc_countdown_cnt_r <= 32'd0;
            alert_blink_cnt      <= 32'd0;
            alert_blink_bit_r    <= 1'b0;

            calc_force_mode_pulse <= 1'b0;
        end else begin
            calc_op_disp_pulse <= 1'b0;
            calc_op_tx_start   <= 1'b0;

            calc_prompt_start  <= 1'b0;
            calc_send_pulse    <= 1'b0;
            calc_info_start    <= 1'b0;
            calc_word_txStart  <= 1'b0;
            calc_scalar_disp_en<= 1'b0;
            calc_force_mode_pulse <= 1'b0;
            calc_result_send_pulse <= 1'b0;

            calc_nm_start      <= 1'b0;
            calc_id_start      <= 1'b0;

            // Alert blink generator (runs only while countdown is active)
            if (mode_state != MODE_CALC) begin
                alert_blink_cnt   <= 32'd0;
                alert_blink_bit_r <= 1'b0;
            end else if (calc_countdown_en_r) begin
                if (alert_blink_cnt < ALERT_BLINK_HALF_CYCLES - 1) begin
                    alert_blink_cnt <= alert_blink_cnt + 1'b1;
                end else begin
                    alert_blink_cnt   <= 32'd0;
                    alert_blink_bit_r <= ~alert_blink_bit_r;
                end
            end else begin
                alert_blink_cnt   <= 32'd0;
                alert_blink_bit_r <= 1'b0;
            end

            // Countdown timer (10s -> 0s). If time runs out before the user confirms the first
            // re-entry step, force returning to CAL op selection start (re-show "CAL" for 1s).
            if (mode_state != MODE_CALC) begin
                calc_countdown_en_r  <= 1'b0;
                calc_countdown_sec_r <= 5'd0;
                calc_countdown_cnt_r <= 32'd0;
            end else if (calc_countdown_en_r) begin
                if (calc_countdown_cnt_r < ONE_SEC_CYCLES - 1) begin
                    calc_countdown_cnt_r <= calc_countdown_cnt_r + 1'b1;
                end else begin
                    calc_countdown_cnt_r <= 32'd0;
                    if (calc_countdown_sec_r != 5'd0) begin
                        calc_countdown_sec_r <= calc_countdown_sec_r - 1'b1;
                    end else begin
                        // timeout at 0
                        calc_countdown_en_r  <= 1'b0;
                        calc_countdown_cnt_r <= 32'd0;

                        // Reset to CAL start (no op selected)
                        calc_state          <= CALC_WAIT_OP;
                        calc_selected_char  <= 8'h00;
                        calc_op_tx_pending  <= 1'b0;
                        calc_word_req       <= 1'b0;
                        calc_word_active    <= 1'b0;
                        calc_word_idx       <= 3'd0;
                        calc_prompt_req     <= 1'b0;
                        calc_info_req       <= 1'b0;
                        calc_info_seen_busy <= 1'b0;
                        calc_flow           <= CALC_FLOW_IDLE;
                        calc_operand_idx    <= 1'b0;
                        calc_m_ready        <= 1'b0;
                        calc_n_ready        <= 1'b0;
                        calc_id_ready       <= 1'b0;
                        calc_prep_timer     <= 2'd0;

                        // Re-show "CAL" for 1 second
                        calc_force_mode_pulse <= 1'b1;
                    end
                end
            end

            // If we leave CALC mode (currently only via reset), return to selection
            if (mode_state != MODE_CALC) begin
                calc_state         <= CALC_WAIT_OP;
                calc_op_tx_pending <= 1'b0;
                calc_selected_char  <= 8'h00;

                // cancel CALC flow helpers
                calc_flow          <= CALC_FLOW_IDLE;
                calc_prompt_req    <= 1'b0;
                calc_info_req      <= 1'b0;
                calc_info_seen_busy<= 1'b0;
                calc_word_req      <= 1'b0;
                calc_word_active   <= 1'b0;
                calc_word_idx      <= 3'd0;
                calc_prep_timer    <= 2'd0;

                calc_wait_rand     <= 1'b0;
                calc_wait_rand_scalar <= 1'b0;
                rand_scalar_active <= 1'b0;

                calc_countdown_en_r  <= 1'b0;
                calc_countdown_sec_r <= 5'd0;
                calc_countdown_cnt_r <= 32'd0;

                calc_exit_to_default <= 1'b0;
            end else begin
                // Default: keep exit request until mode_state consumes it.
                if (mode_state == MODE_DEFAULT) begin
                    calc_exit_to_default <= 1'b0;
                end

                // In CALC mode, wait for user to choose an operation via switches and confirm via button
                if (calc_state == CALC_WAIT_OP) begin
                    if (btn_pulse) begin
                        if ( (mode_sw == 5'b00001) ||
                             (mode_sw == 5'b00010) ||
                             (mode_sw == 5'b00100) ||
                             (mode_sw == 5'b01000) ||
                             (mode_sw == 5'b10000) )
                        begin
                            calc_state         <= sw_to_calc_op(mode_sw);
                            calc_op_disp_char  <= calc_op_to_char(sw_to_calc_op(mode_sw));
                            calc_op_disp_pulse <= 1'b1;

                            // Latch for continuous display until exit CALC
                            calc_selected_char <= calc_op_to_char(sw_to_calc_op(mode_sw));

                            // Queue UART send of the op letter (single byte)
                            calc_op_tx_pending      <= 1'b1;
                            calc_op_tx_pending_char <= calc_op_to_char(sw_to_calc_op(mode_sw));

                            // Initialize flow after op selection
                            if (sw_to_calc_op(mode_sw) == CALC_OP_CONV) begin
                                calc_flow        <= CALC_FLOW_CONV_RESET;
                                conv_input_cnt   <= 4'd0;
                                calc_op1_m       <= 8'd3;
                                calc_op1_n       <= 8'd3;
                                calc_info_req    <= 1'b0; // No info needed
                            end else begin
                                calc_flow        <= CALC_FLOW_SEND_INFO;
                                calc_info_req    <= 1'b1;
                            end
                            
                            calc_info_seen_busy <= 1'b0;
                            calc_prompt_req  <= 1'b0;
                            calc_m_ready     <= 1'b0;
                            calc_n_ready     <= 1'b0;
                            calc_id_ready    <= 1'b0;
                            calc_operand_idx <= 1'b0;
                            calc_prep_timer  <= 2'd0;
                            if (sw_to_calc_op(mode_sw) != CALC_OP_CONV) begin
                                calc_op1_m        <= 8'd1;
                                calc_op1_n        <= 8'd1;
                            end
                            calc_op2_m        <= 8'd1;
                            calc_op2_n        <= 8'd1;
                            calc_countdown_en_r  <= 1'b0;
                            calc_countdown_sec_r <= 5'd0;
                            calc_countdown_cnt_r <= 32'd0;
                            calc_need_second <= (sw_to_calc_op(mode_sw) == CALC_OP_ADD) ||
                                               (sw_to_calc_op(mode_sw) == CALC_OP_MUL);
                            calc_is_scalar   <= (sw_to_calc_op(mode_sw) == CALC_OP_SCALAR);
                            rand_scalar_active <= 1'b0;

                            // Clear previous operands/results
                            calc_op1_matrix_tight <= {MATRIX_WIDTH{1'b0}};
                            calc_op2_matrix_tight <= {MATRIX_WIDTH{1'b0}};
                            calc_result_matrix_tight <= {MATRIX_WIDTH{1'b0}};
                            calc_result_m <= 8'd1;
                            calc_result_n <= 8'd1;
                            calc_exit_to_default <= 1'b0;
                        end
                    end
                end

                // CALC flow FSM (runs after op is chosen)
                if (calc_state != CALC_WAIT_OP) begin
                    case (calc_flow)
                        CALC_FLOW_IDLE: begin
                            // Wait here only if op was selected before reset; start flow.
                            calc_flow     <= CALC_FLOW_SEND_INFO;
                            calc_info_req <= 1'b1;
                            calc_info_seen_busy <= 1'b0;
                        end

                        CALC_FLOW_SEND_INFO: begin
                            if (calc_info_uart_busy) begin
                                calc_info_seen_busy <= 1'b1;
                            end
                            
                            if (calc_info_seen_busy && !calc_info_uart_busy && !calc_info_req) begin
                                calc_prompt_req     <= 1'b1;
                                calc_prompt_req_sel <= PROMPT_WAIT1;
                                calc_nm_start       <= 1'b1; // Start NM RX
                                calc_flow           <= CALC_FLOW_GET_DIMS;
                            end
                        end

                        CALC_FLOW_GET_DIMS: begin
                            if (calc_nm_done) begin
                                if (!calc_nm_error) begin
                                    // Latch M and N
                                    calc_req_m <= calc_nm_m;
                                    calc_req_n <= calc_nm_n;
                                    calc_m_pending <= calc_nm_m;
                                    calc_n_pending <= calc_nm_n;
                                    
                                    if (calc_operand_idx == 1'b0) begin
                                        calc_op1_m <= calc_nm_m;
                                        calc_op1_n <= calc_nm_n;
                                    end else begin
                                        calc_op2_m <= calc_nm_m;
                                        calc_op2_n <= calc_nm_n;
                                    end

                                    // Cancel countdown if active (re-entry started)
                                    if (calc_countdown_en_r) begin
                                        calc_countdown_en_r  <= 1'b0;
                                        calc_countdown_sec_r <= 5'd0;
                                        calc_countdown_cnt_r <= 32'd0;
                                    end

                                    // Compatibility check for 2nd operand
                                    if (calc_need_second && (calc_operand_idx == 1'b1)) begin
                                        if (!calc_dims_ok(calc_state, calc_op1_m, calc_op1_n, calc_nm_m, calc_nm_n)) begin
                                            // Invalid dims -> Error/Countdown
                                            calc_countdown_en_r  <= 1'b1;
                                            calc_countdown_sec_r <= 5'd10;
                                            calc_countdown_cnt_r <= 32'd0;

                                            calc_operand_idx <= 1'b0;
                                            calc_prompt_req     <= 1'b1;
                                            calc_prompt_req_sel <= PROMPT_WAIT1;
                                            calc_nm_start       <= 1'b1; // Restart RX
                                            calc_flow        <= CALC_FLOW_GET_DIMS;
                                            calc_prep_timer  <= 2'd0;
                                        end else begin
                                            // Valid -> Proceed
                                            calc_prompt_req  <= 1'b1;
                                            calc_prompt_req_sel <= PROMPT_DISPLAY;
                                            calc_flow        <= CALC_FLOW_PREP;
                                            calc_prep_timer  <= 2'd0;
                                            calc_countdown_en_r  <= 1'b0;
                                            calc_countdown_sec_r <= 5'd0;
                                            calc_countdown_cnt_r <= 32'd0;
                                        end
                                    end else begin
                                        // First operand -> Proceed
                                        calc_prompt_req  <= 1'b1;
                                        calc_prompt_req_sel <= PROMPT_DISPLAY;
                                        calc_flow        <= CALC_FLOW_PREP;
                                        calc_prep_timer  <= 2'd0;
                                    end
                                end else begin
                                    // Error -> Retry
                                    calc_prompt_req     <= 1'b1;
                                    calc_prompt_req_sel <= PROMPT_WAIT1;
                                    calc_nm_start       <= 1'b1; // Restart RX
                                    calc_flow           <= CALC_FLOW_GET_DIMS;
                                end
                            end
                        end


                        CALC_FLOW_PREP: begin
                            // Wait a few cycles for matrixIO to settle after setting dims.
                            if (calc_prep_timer < 2'd3) begin
                                calc_prep_timer <= calc_prep_timer + 1'b1;
                            end else begin
                                if (storage_count == 3'd0) begin
                                    calc_prompt_req     <= 1'b1;
                                    calc_prompt_req_sel <= PROMPT_WAIT1;
                                    calc_nm_start       <= 1'b1; // Restart RX
                                    calc_flow           <= CALC_FLOW_GET_DIMS;
                                    calc_prep_timer     <= 2'd0;
                                end else begin
                                    calc_list_cursor <= 3'd0;
                                    calc_flow        <= CALC_FLOW_LIST_ARM;
                                    calc_prep_timer  <= 2'd0;
                                end
                            end
                        end

                        CALC_FLOW_LIST_ARM: begin
                            // Send all matrices for this dimension with their IDs
                            if (calc_list_cursor >= storage_count) begin
                                calc_flow      <= CALC_FLOW_GET_ID;
                                calc_id_start  <= 1'b1; // Start ID RX
                            end else if (!calc_matrix_tx_busy && !calc_prompt_req && !mode_uart_busy &&
                                         !calc_info_uart_busy && !calc_op_tx_busy && !calc_word_txBusy) begin
                                calc_sel_cursor <= calc_list_cursor;
                                calc_flow       <= CALC_FLOW_LIST_SEND;
                            end
                        end

                        CALC_FLOW_LIST_SEND: begin
                            calc_send_pulse <= 1'b1;
                            calc_seen_matrix_busy <= 1'b0;
                            calc_flow       <= CALC_FLOW_LIST_WAIT;
                        end

                        CALC_FLOW_LIST_WAIT: begin
                            if (calc_matrix_tx_busy) begin
                                calc_seen_matrix_busy <= 1'b1;
                            end
                            if (calc_seen_matrix_busy && !calc_matrix_tx_busy) begin
                                calc_list_cursor <= calc_list_cursor + 1'b1;
                                calc_flow        <= CALC_FLOW_LIST_ARM;
                            end
                        end

                        CALC_FLOW_GET_ID: begin
                            // User types matrix id (1..5)
                            if (rand_detected) begin
                                rand_max_val    <= {5'd0, storage_count} - 8'd1; // 0..(count-1)
                                rand_gen_enable <= 1'b1;
                                calc_wait_rand  <= 1'b1;
                            end else if (calc_wait_rand) begin
                                rand_gen_enable <= 1'b0;
                                calc_wait_rand  <= 1'b0;
                                // Use first byte of random data. Add 1 to get 1..count
                                calc_sel_cursor <= rand_data_flat[2:0]; // 0..count-1
                                calc_id_pending <= rand_data_flat[7:0] + 8'd1;
                                calc_flow       <= CALC_FLOW_SHOW_ONE_ARM;
                            end else if (calc_id_done) begin
                                if (!calc_id_error) begin
                                    calc_sel_cursor <= calc_id_val[2:0] - 3'd1;
                                    calc_id_pending <= calc_id_val;
                                    calc_flow       <= CALC_FLOW_SHOW_ONE_ARM;
                                end else begin
                                    // Error -> Retry
                                    calc_id_start <= 1'b1; // Restart RX
                                end
                            end
                        end


                        CALC_FLOW_SHOW_ONE_ARM: begin
                            if (!calc_matrix_tx_busy && !calc_result_tx_busy && !calc_prompt_req && !mode_uart_busy &&
                                !calc_info_uart_busy && !calc_op_tx_busy && !calc_word_txBusy) begin
                                // Latch selected operand matrix for computation (tight packed)
                                if (calc_operand_idx == 1'b0) begin
                                    calc_op1_matrix_tight <= calc_matrix_slice;
                                end else begin
                                    calc_op2_matrix_tight <= calc_matrix_slice;
                                end
                                calc_send_pulse <= 1'b1;
                                calc_seen_matrix_busy <= 1'b0;
                                calc_flow       <= CALC_FLOW_SHOW_ONE_WAIT;
                            end
                        end

                        CALC_FLOW_SHOW_ONE_WAIT: begin
                            if (calc_matrix_tx_busy) begin
                                calc_seen_matrix_busy <= 1'b1;
                            end
                            if (calc_seen_matrix_busy && !calc_matrix_tx_busy) begin
                                // Decide next step based on op
                                if (calc_is_scalar) begin
                                    calc_flow <= CALC_FLOW_SCALAR_WAIT;
                                end else if (calc_need_second && (calc_operand_idx == 1'b0)) begin
                                    // Need second matrix: repeat full dimension selection for operand2
                                    calc_operand_idx <= 1'b1;
                                    calc_m_ready     <= 1'b0;
                                    calc_n_ready     <= 1'b0;
                                    calc_id_ready    <= 1'b0;
                                    calc_prompt_req     <= 1'b1;
                                    calc_prompt_req_sel <= PROMPT_WAIT1;
                                    calc_nm_start       <= 1'b1; // Restart RX
                                    calc_flow           <= CALC_FLOW_GET_DIMS;
                                end else begin
                                    calc_flow <= CALC_FLOW_COMPUTE_LATCH;
                                    calc_compute_start <= 1'b1;
                                end
                            end
                        end

                        CALC_FLOW_SCALAR_WAIT: begin
                            // Live show scalar via 7-seg; confirm button to finalize.
                            calc_scalar_disp_en <= 1'b1;

                            if (rand_detected) begin
                                rand_max_val          <= 8'd9;
                                rand_gen_enable       <= 1'b1;
                                calc_wait_rand_scalar <= 1'b1;
                            end else if (calc_wait_rand_scalar) begin
                                rand_gen_enable       <= 1'b0;
                                calc_wait_rand_scalar <= 1'b0;
                                rand_scalar_stored    <= rand_data_flat[3:0];
                                rand_scalar_active    <= 1'b1;
                            end

                            if (btn_pulse) begin
                                if (calc_scalar_val <= 4'd9) begin
                                    calc_flow     <= CALC_FLOW_COMPUTE_LATCH;
                                    calc_compute_start <= 1'b1;
                                end
                            end
                        end

                        CALC_FLOW_CONV_RESET: begin
                            conv_input_cnt <= 4'd0;
                            calc_flow <= CALC_FLOW_CONV_INPUT;
                        end

                        CALC_FLOW_CONV_INPUT: begin
                            if (rx_done && rx_digit_valid_any) begin
                                if (conv_input_cnt < 4'd9) begin
                                    calc_op1_matrix_tight[conv_input_cnt*8 +: 8] <= rx_digit_val_any;
                                    conv_input_cnt <= conv_input_cnt + 1'b1;
                                end
                            end
                            if (conv_input_cnt >= 4'd9) begin
                                calc_flow <= CALC_FLOW_CONV_CONFIRM;
                            end
                        end

                        CALC_FLOW_CONV_CONFIRM: begin
                            if (btn_pulse) begin
                                calc_flow <= CALC_FLOW_COMPUTE_LATCH;
                                calc_compute_start <= 1'b1;
                            end
                        end

                        CALC_FLOW_COMPUTE_LATCH: begin
                            // Latch computation results (combinational units) then send over UART.
                            if (calc_res_valid) begin
                                calc_result_m <= calc_res_m;
                                calc_result_n <= calc_res_n;
                                if (calc_state == CALC_OP_CONV) begin
                                    calc_result_matrix_tight <= calc_res_padded;
                                end else begin
                                    // Simplified: assume tight packing is just the data
                                    calc_result_matrix_tight <= calc_res_padded;
                                end
                                calc_flow <= CALC_FLOW_RESULT_SEND_ARM;
                                calc_compute_start <= 1'b0;
                            end else begin
                                if (calc_state == CALC_OP_CONV) begin
                                    calc_compute_start <= 1'b0;
                                end else begin
                                    // Unexpected invalid -> restart operand selection
                                    calc_prompt_req     <= 1'b1;
                                    calc_prompt_req_sel <= PROMPT_WAIT1;
                                    calc_operand_idx    <= 1'b0;
                                    calc_nm_start       <= 1'b1; // Restart RX
                                    calc_flow           <= CALC_FLOW_GET_DIMS;
                                    calc_compute_start <= 1'b0;
                                end
                            end
                        end

                        CALC_FLOW_RESULT_SEND_ARM: begin
                            if (!calc_result_tx_busy && !calc_matrix_tx_busy && !calc_prompt_req && !mode_uart_busy &&
                                !calc_info_uart_busy && !calc_op_tx_busy && !calc_word_txBusy) begin
                                calc_result_send_pulse <= 1'b1;
                                calc_seen_result_busy <= 1'b0;
                                calc_flow <= CALC_FLOW_RESULT_SEND_WAIT;
                            end
                        end

                        CALC_FLOW_RESULT_SEND_WAIT: begin
                            if (calc_result_tx_busy) begin
                                calc_seen_result_busy <= 1'b1;
                            end
                            if (calc_seen_result_busy && !calc_result_tx_busy) begin
                                calc_flow <= CALC_FLOW_DONE_WAIT_CONFIRM;
                            end
                        end

                        CALC_FLOW_DONE_WAIT_CONFIRM: begin
                            // Wait user confirmation to return to DEFAULT mode.
                            if (btn_pulse) begin
                                calc_exit_to_default <= 1'b1;
                                // Prepare CALC internal state for next entry
                                calc_state         <= CALC_WAIT_OP;
                                calc_selected_char <= 8'h00;
                                calc_op_tx_pending <= 1'b0;
                                calc_prompt_req    <= 1'b0;
                                calc_info_req      <= 1'b0;
                                calc_info_seen_busy<= 1'b0;
                                calc_flow          <= CALC_FLOW_IDLE;
                                calc_operand_idx   <= 1'b0;
                                calc_m_ready       <= 1'b0;
                                calc_n_ready       <= 1'b0;
                                calc_id_ready      <= 1'b0;
                                calc_countdown_en_r  <= 1'b0;
                                calc_countdown_sec_r <= 5'd0;
                                calc_countdown_cnt_r <= 32'd0;
                            end
                        end

                        default: calc_flow <= CALC_FLOW_IDLE;
                    endcase
                end

                // Fire the UART TX when bus is available.
                // Avoid collisions with mode notifier (e.g., freshly entered CALC).
                if (calc_op_tx_pending && !calc_op_tx_busy && !mode_uart_busy &&
                    !calc_prompt_uart_busy && !calc_info_uart_busy && !calc_matrix_tx_busy && !calc_word_txBusy) begin
                    calc_op_tx_data    <= calc_op_tx_pending_char;
                    calc_op_tx_start   <= 1'b1;
                    calc_op_tx_pending <= 1'b0;
                end

                // Dispatch CALC prompt when UART is clear
                if (!calc_matrix_tx_busy && !calc_result_tx_busy && !mode_uart_busy && !calc_info_uart_busy && !calc_op_tx_busy && !calc_word_txBusy &&
                    calc_prompt_req && mode_state == MODE_CALC) begin
                    calc_prompt_sel   <= calc_prompt_req_sel;
                    calc_prompt_start <= 1'b1;
                    calc_prompt_req   <= 1'b0;
                end

                // Dispatch CALC inventory info when UART is clear
                if (!calc_matrix_tx_busy && !calc_result_tx_busy && !mode_uart_busy && !calc_prompt_uart_busy && !calc_op_tx_busy && !calc_word_txBusy &&
                    calc_info_req && mode_state == MODE_CALC) begin
                    calc_info_start <= 1'b1;
                    calc_info_req   <= 1'b0;
                end

                // Fake "calc\n" sender (multi-byte) driven here to avoid multi-driver regs
                if (mode_state == MODE_CALC) begin
                    if (!calc_word_active) begin
                        if (calc_word_req && !calc_word_txBusy &&
                            !mode_uart_busy && !calc_prompt_uart_busy && !calc_info_uart_busy && !calc_matrix_tx_busy && !calc_op_tx_busy) begin
                            calc_word_active  <= 1'b1;
                            calc_word_req     <= 1'b0;
                            calc_word_idx     <= 3'd0;
                            calc_word_txData  <= calc_word_char(3'd0);
                            calc_word_txStart <= 1'b1;
                        end
                    end else begin
                        if (!calc_word_txBusy) begin
                            if (calc_word_idx < 3'd4) begin
                                calc_word_idx     <= calc_word_idx + 1'b1;
                                calc_word_txData  <= calc_word_char(calc_word_idx + 1'b1);
                                calc_word_txStart <= 1'b1;
                            end else begin
                                // idx==4 was last byte (\n)
                                calc_word_active <= 1'b0;
                                calc_word_idx    <= 3'd0;
                            end
                        end
                    end
                end
            end
        end
    end

    // --------------------
    // GEN controller (Random generation + store + UART output)
    // --------------------
    localparam GEN_IDLE          = 4'd0;
    localparam GEN_ENTRY_WAIT1   = 4'd1;
    localparam GEN_WAIT_INPUT    = 4'd2; // Replaces WAIT_M/N/K
    // localparam GEN_WAIT_M        = 4'd2;
    // localparam GEN_WAIT_N        = 4'd3;
    // localparam GEN_WAIT_K        = 4'd4;
    localparam GEN_GEN_PULSE     = 4'd5;
    localparam GEN_GEN_CAPTURE   = 4'd6;
    localparam GEN_SEND_GENWORD  = 4'd7;
    localparam GEN_SEND_ARM      = 4'd8;
    localparam GEN_SEND_PULSE    = 4'd9;
    localparam GEN_SEND_WAIT     = 4'd10;

    reg [3:0] gen_state;
    reg [7:0] gen_k;
    reg [2:0] gen_gen_idx;
    reg [2:0] gen_send_idx;

    // reg       gen_prompt_start; // Moved to top
    // reg [2:0] gen_prompt_sel;   // Moved to top
    reg       gen_prompt_req;
    reg [2:0] gen_prompt_req_sel;

    // reg       gen_send_pulse; // Moved to top
    reg       gen_seen_matrix_busy;

    // Random generator control
    reg       rand_enable;
    wire [199:0] rand_matrix;

    // Buffer newly generated matrices (up to 5)
    reg [199:0] gen_buf [0:4];

    // GEN TX modules signals
    // wire gen_prompt_uart_tx; // Moved to top
    // wire gen_matrix_uart_tx; // Moved to top

    assign gen_tx_busy = gen_prompt_uart_busy || gen_matrix_busy_wire;

    // GEN RX module signals
    reg        gen_rx_start;

    GenerationUartRx u_gen_rx (
        .clk(clk),
        .uartRxRstN(rst_n),
        .rx(uart_rx),
        .rxStart(gen_rx_start),
        .cntLimit({5'd0, user_max_limit}),
        .m(gen_rx_m),
        .n(gen_rx_n),
        .cnt(gen_rx_cnt),
        .rxDone(gen_rx_done),
        .rxError(gen_rx_error)
    );

    // 璇风‘淇濅綘鏈� random.v
    random u_rand (
        .clk(clk),
        .rst(storage_rst),
        .genEnable(rand_enable),
        .max_val(8'd9),
        .readData(rand_matrix)
    );

    // ShowUartTx #(
    //     .CLK_FREQ_HZ(CLK_FREQ_HZ),
    //     .BAUD_RATE(115200)
    // ) u_gen_prompt (
    //     .clk(clk),
    //     .uartTxRstN(rst_n),
    //     .sendOne(1'b0),
    //     .promptStart(gen_prompt_start),
    //     .promptSel(gen_prompt_sel),
    //     .uartTx(gen_prompt_uart_tx),
    //     .busy(gen_prompt_uart_busy)
    // );

    function automatic [199:0] sel_gen_buf;
        input [2:0] idx;
        begin
            case (idx)
                3'd0: sel_gen_buf = gen_buf[0];
                3'd1: sel_gen_buf = gen_buf[1];
                3'd2: sel_gen_buf = gen_buf[2];
                3'd3: sel_gen_buf = gen_buf[3];
                default: sel_gen_buf = gen_buf[4];
            endcase
        end
    endfunction

    wire [199:0] gen_matrix_to_send;
    assign gen_matrix_to_send = sel_gen_buf(gen_send_idx);

    // MatrixUartTx reads matrixData continuously while busy; keep its inputs
    // stable for the entire transmission by latching before sendOne.
    // reg [199:0] gen_matrix_latched; // Moved to top
    // reg [7:0]   gen_m_latched;      // Moved to top
    // reg [7:0]   gen_n_latched;      // Moved to top
    // reg [7:0]   gen_id_latched;     // Moved to top

    // MatrixUartTx u_gen_matrix (
    //     .clk(clk),
    //     .uartTxRstN(rst_n),
    //     .sendOne(gen_send_pulse),
    //     .matrixData(gen_matrix_latched),
    //     .m(gen_m_latched),
    //     .n(gen_n_latched),
    //     .id(gen_id_latched),
    //     .ifID(1'b1),
    //     .ifNM(1'b1),
    //     .uartTx(gen_matrix_uart_tx),
    //     .busy(gen_matrix_busy_wire)
    // );

    // GEN controller FSM
    integer gi;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gen_state          <= GEN_IDLE;
            gen_m              <= 8'd1;
            gen_n              <= 8'd1;
            gen_k              <= 8'd1;
            gen_gen_idx        <= 3'd0;
            gen_send_idx       <= 3'd0;
            gen_send_pulse     <= 1'b0;
            gen_seen_matrix_busy <= 1'b0;
            gen_prompt_start   <= 1'b0;
            gen_prompt_sel     <= PROMPT_WAIT1;
            gen_prompt_req     <= 1'b0;
            gen_prompt_req_sel <= PROMPT_WAIT1;
            rand_enable        <= 1'b0;
            gen_write_req      <= 1'b0;
            gen_write_dimX     <= 8'd1;
            gen_write_dimY     <= 8'd1;
            gen_write_wdata    <= {MATRIX_WIDTH{1'b0}};
            // Removed loop for LUT optimization
            gen_buf[0] <= {MATRIX_WIDTH{1'b0}};
            gen_buf[1] <= {MATRIX_WIDTH{1'b0}};
            gen_buf[2] <= {MATRIX_WIDTH{1'b0}};
            gen_buf[3] <= {MATRIX_WIDTH{1'b0}};
            gen_buf[4] <= {MATRIX_WIDTH{1'b0}};
            
            gen_matrix_latched <= {MATRIX_WIDTH{1'b0}};
            gen_m_latched      <= 8'd1;
            gen_n_latched      <= 8'd1;
            gen_id_latched     <= 8'd1;
        end else begin
            gen_send_pulse   <= 1'b0;
            gen_prompt_start <= 1'b0;
            gen_write_req    <= 1'b0;
            rand_enable      <= 1'b0;
            gen_rx_start     <= 1'b0;

            // If we leave GEN mode, cancel pending prompt requests
            if (mode_state != MODE_GEN) begin
                gen_prompt_req <= 1'b0;
                gen_seen_matrix_busy <= 1'b0;
            end

            case (gen_state)
                GEN_IDLE: begin
                    // 銆愬叧閿慨鏀广�戝繀椤荤瓑寰� mode_uart_busy 缁撴潫锛屽惁鍒� GEN 娑堟伅浼氳瑕嗙洊
                    if (mode_state == MODE_GEN && !mode_uart_busy) begin
                        gen_prompt_req     <= 1'b1;
                        gen_prompt_req_sel <= PROMPT_GENERATE;
                        gen_state          <= GEN_ENTRY_WAIT1;
                    end
                end

                GEN_ENTRY_WAIT1: begin
                    if (mode_state != MODE_GEN) begin
                        gen_state <= GEN_IDLE;
                    end else if (!gen_prompt_req && !gen_prompt_uart_busy) begin
                        gen_prompt_req     <= 1'b1;
                        gen_prompt_req_sel <= PROMPT_WAIT1;
                        gen_rx_start       <= 1'b1; // Start RX
                        gen_state          <= GEN_WAIT_INPUT;
                    end
                end

                GEN_WAIT_INPUT: begin
                    if (mode_state != MODE_GEN) begin
                        gen_state <= GEN_IDLE;
                    end else if (gen_rx_done) begin
                        if (!gen_rx_error) begin
                            gen_m <= gen_rx_m;
                            gen_n <= gen_rx_n;
                            gen_k <= gen_rx_cnt;
                            gen_gen_idx <= 3'd0;
                            gen_send_idx<= 3'd0;
                            gen_state   <= GEN_GEN_PULSE;
                        end else begin
                            // Error -> Retry (re-prompt)
                            gen_prompt_req     <= 1'b1;
                            gen_prompt_req_sel <= PROMPT_WAIT1;
                            gen_state          <= GEN_ENTRY_WAIT1; // Will trigger start again
                        end
                    end
                end


                GEN_GEN_PULSE: begin
                    if (mode_state != MODE_GEN) begin
                        gen_state <= GEN_IDLE;
                    end else begin
                        rand_enable <= 1'b1;
                        gen_state   <= GEN_GEN_CAPTURE;
                    end
                end

                GEN_GEN_CAPTURE: begin
                    if (mode_state != MODE_GEN) begin
                        gen_state <= GEN_IDLE;
                    end else begin
                        gen_buf[gen_gen_idx] <= rand_matrix;

                        // Also write to storage
                        gen_write_req   <= 1'b1;
                        gen_write_dimX  <= gen_m;
                        gen_write_dimY  <= gen_n;
                        gen_write_wdata <= rand_matrix;

                        if (gen_gen_idx + 1'b1 < gen_k[2:0]) begin
                            gen_gen_idx <= gen_gen_idx + 1'b1;
                            gen_state   <= GEN_GEN_PULSE;
                        end else begin
                            // Finished generation; now send "generate" then matrices
                            gen_prompt_req     <= 1'b1;
                            gen_prompt_req_sel <= PROMPT_GENERATE;
                            gen_state          <= GEN_SEND_GENWORD;
                        end
                    end
                end

                GEN_SEND_GENWORD: begin
                    if (mode_state != MODE_GEN) begin
                        gen_state <= GEN_IDLE;
                    end else if (!gen_prompt_req && !gen_prompt_uart_busy) begin
                        gen_state <= GEN_SEND_ARM;
                    end
                end

                GEN_SEND_ARM: begin
                    if (mode_state != MODE_GEN) begin
                        gen_state <= GEN_IDLE;
                    end else if (gen_send_idx >= gen_k[2:0]) begin
                        // Done; restart for next input
                        gen_state          <= GEN_ENTRY_WAIT1;
                    end else if (!gen_tx_busy && !gen_prompt_req && !mode_uart_busy) begin
                        gen_matrix_latched <= sel_gen_buf(gen_send_idx);
                        gen_m_latched      <= gen_m;
                        gen_n_latched      <= gen_n;
                        gen_id_latched     <= ({5'b0, gen_send_idx} + 8'd1);
                        gen_seen_matrix_busy <= 1'b0;
                        gen_state          <= GEN_SEND_PULSE;
                    end
                end

                GEN_SEND_PULSE: begin
                    if (mode_state != MODE_GEN) begin
                        gen_state <= GEN_IDLE;
                    end else begin
                        gen_send_pulse <= 1'b1;
                        gen_state      <= GEN_SEND_WAIT;
                    end
                end

                GEN_SEND_WAIT: begin
                    if (mode_state != MODE_GEN) begin
                        gen_state <= GEN_IDLE;
                    end else begin
                        if (gen_matrix_busy_wire) begin
                            gen_seen_matrix_busy <= 1'b1;
                        end
                        if (gen_seen_matrix_busy && !gen_matrix_busy_wire) begin
                            gen_send_idx <= gen_send_idx + 1'b1;
                            gen_state    <= GEN_SEND_ARM;
                        end
                    end
                end

                default: gen_state <= GEN_IDLE;
            endcase

            // Dispatch GEN prompt request when UART is clear
            if (!gen_tx_busy && !mode_uart_busy && gen_prompt_req && mode_state == MODE_GEN) begin
                gen_prompt_sel   <= gen_prompt_req_sel;
                gen_prompt_start <= 1'b1;
                gen_prompt_req   <= 1'b0;
            end
        end
    end

    // --------------------
    // Error pulse generation (drives LED blink via error_blink)
    // --------------------
    wire err_default_mode_sel;
    wire err_show_dim;
    wire err_calc_op_sel;
    wire err_calc_uart_digit;
    wire err_calc_id_range;
    wire err_calc_scalar_range;
    wire err_gen_digit;

    // DEFAULT: invalid mode selection (not exactly one of the 5 mode switches).
    assign err_default_mode_sel = (mode_state == MODE_DEFAULT) && btn_pulse && !mode_sw_valid_onehot;

    // SHOW: invalid dimension input (non-ignored char, not in 1..5).
    assign err_show_dim = (mode_state == MODE_SHOW) &&
                          ((show_state == SHOW_WAIT_M) || (show_state == SHOW_WAIT_N)) &&
                          rx_done && !rx_digit_ok && !rx_is_ignore;

    // CALC: invalid op selection (only while waiting for op).
    assign err_calc_op_sel = (mode_state == MODE_CALC) && (calc_state == CALC_WAIT_OP) &&
                             btn_pulse && !mode_sw_valid_onehot;

    // GEN: invalid UART digit during M/N/K entry.
    assign err_gen_digit = (mode_state == MODE_GEN) && (gen_state == GEN_WAIT_INPUT) && gen_rx_done && gen_rx_error;

    // CALC: invalid UART digit during dimension / id entry (non-ignored, not 1..5).
    assign err_calc_uart_digit = (mode_state == MODE_CALC) &&
                                 (
                                    ((calc_flow == CALC_FLOW_GET_DIMS) && calc_nm_done && calc_nm_error)
                                    ||
                                    ((calc_flow == CALC_FLOW_GET_ID) && calc_id_done && calc_id_error)
                                 );

    // CALC: invalid matrix id confirm (out of current storage_count range).
    assign err_calc_id_range = 1'b0; // Handled by IdUartRx

    // CALC: invalid scalar confirm (>9 shows 'E' on 7-seg; confirm should error but not accept).
    assign err_calc_scalar_range = (mode_state == MODE_CALC) && (calc_flow == CALC_FLOW_SCALAR_WAIT) &&
                                   btn_pulse && (calc_scalar_val > 4'd9);

    assign error_pulse = err_default_mode_sel || err_show_dim || err_calc_op_sel ||
                         err_calc_uart_digit || err_calc_id_range || err_calc_scalar_range || err_gen_digit || setup_error_pulse;

    wire show_uart_sel_prompt;
    assign show_uart_sel_prompt = prompt_uart_busy || prompt_start;

    wire show_uart_sel_info;
    assign show_uart_sel_info = show_info_uart_busy || show_info_start;
    
    wire gen_uart_sel_prompt;
    assign gen_uart_sel_prompt = gen_prompt_uart_busy || gen_prompt_start;

          // UART mux
          wire calc_uart_sel_info;
          assign calc_uart_sel_info = calc_info_uart_busy || calc_info_start;

          wire calc_uart_sel_prompt;
          assign calc_uart_sel_prompt = calc_prompt_uart_busy || calc_prompt_start;

        wire calc_uart_sel_word;
        assign calc_uart_sel_word = calc_word_active || calc_word_txBusy || calc_word_txStart;

          wire calc_uart_sel_op;
          assign calc_uart_sel_op = calc_op_tx_busy || calc_op_tx_start;

                wire calc_uart_sel_result;
                assign calc_uart_sel_result = calc_result_tx_busy || calc_result_send_pulse;

    wire store_uart_sel_matrix;
    assign store_uart_sel_matrix = shared_matrix_busy || store_send_pulse || (store_state_fsm == STORE_WAIT && !store_seen_matrix_busy);

    // 銆愬叧閿慨鏀广�憁ode_uart_busy 浼樺厛绾ф渶楂橈紝淇濊瘉 GEN/SHOW 鐘舵�佸悕鑳藉鍙戝嚭鍘�
    assign uart_tx = mode_uart_busy ? mode_uart_tx :
                     (mode_state == MODE_SHOW) ? (show_uart_sel_info ? show_info_uart_tx : (show_uart_sel_prompt ? prompt_uart_tx : matrix_uart_tx)) :
                     (mode_state == MODE_GEN)  ? (gen_uart_sel_prompt ? gen_prompt_uart_tx : gen_matrix_uart_tx) :
                     (mode_state == MODE_STORE)? (store_uart_sel_matrix ? matrix_uart_tx : mode_uart_tx) :
                     (mode_state == MODE_CALC) ? (calc_uart_sel_info ? calc_info_uart_tx :
                                                 (calc_uart_sel_prompt ? calc_prompt_uart_tx :
                                                 (calc_uart_sel_word ? calc_word_uart_tx :
                                                 (calc_uart_sel_op ? calc_op_uart_tx :
                                                 (calc_uart_sel_result ? calc_result_uart_tx :
                                                 (calc_matrix_tx_busy ? calc_matrix_uart_tx : mode_uart_tx)))))) :
                     mode_uart_tx;

endmodule
