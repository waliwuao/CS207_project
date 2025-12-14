`timescale 1ns / 1ps

// Sends matrix inventory info for SHOW mode before user enters dimensions.
// Format example: "3 2*2*1 4*5*2\n"
// - First token: total matrix count across all dimensions
// - Then, for each (m,n) with count>0: " m*n*x" where x is count
// This module does NOT modify matrixIO; it only drives dimX/dimY to read fillState.

module ShowMatrixInfoTx #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 115200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,

    // matrixIO query interface
    output reg  [7:0] dimX,
    output reg  [7:0] dimY,
    input  wire [2:0] count,
    output reg        scan_active,

    // UART output
    output wire       uartTx,
    output wire       busy
);

    localparam integer MAX_DIMS = 25; // 5*5

    // Store counts for each dimension index
    reg [2:0] cnt_mem [0:MAX_DIMS-1];

    reg [4:0] scan_idx;
    reg [1:0] scan_wait;
    reg [7:0] total_count;

    // Decimal digits for total_count (0..125)
    reg [3:0] total_h;
    reg [3:0] total_t;
    reg [3:0] total_o;

    // SEND iteration
    reg [4:0] send_idx;
    reg [2:0] item_phase;

    reg [1:0] total_len;
    reg [1:0] total_stage;

    // Precompute last-scan sum and its decimal digits (used when scan_idx==24)
    wire [7:0]  total_sum_next;
    wire [11:0] total_dec_next;
    assign total_sum_next = total_count + {5'd0, count};
    assign total_dec_next = to_dec3(total_sum_next);

    // UART handshake
    reg       txStart;
    reg [7:0] txData;
    wire      txBusy;

    UartTx #(
        .CLK_FREQ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) u_uart (
        .clk(clk),
        .rstN(rst_n),
        .txStart(txStart),
        .txData(txData),
        .tx(uartTx),
        .txBusy(txBusy)
    );

    // Simple edge detect on start
    reg start_d1, start_d2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_d1 <= 1'b0;
            start_d2 <= 1'b0;
        end else begin
            start_d1 <= start;
            start_d2 <= start_d1;
        end
    end
    wire start_pulse = start_d1 & ~start_d2;

    // Helpers
    function automatic [7:0] digit_ascii;
        input [3:0] d;
        begin
            digit_ascii = 8'h30 + {4'b0, d};
        end
    endfunction

    // Tool-friendly (no / or %) mapping from 0..24 index -> 1..5 digit
    function automatic [3:0] idx_to_m_digit;
        input [4:0] idx;
        begin
            case (idx)
                5'd0,  5'd5,  5'd10, 5'd15, 5'd20: idx_to_m_digit = 4'd1;
                5'd1,  5'd6,  5'd11, 5'd16, 5'd21: idx_to_m_digit = 4'd2;
                5'd2,  5'd7,  5'd12, 5'd17, 5'd22: idx_to_m_digit = 4'd3;
                5'd3,  5'd8,  5'd13, 5'd18, 5'd23: idx_to_m_digit = 4'd4;
                default:                           idx_to_m_digit = 4'd5; // 4,9,14,19,24
            endcase
        end
    endfunction

    function automatic [3:0] idx_to_n_digit;
        input [4:0] idx;
        begin
            case (idx)
                5'd0,  5'd1,  5'd2,  5'd3,  5'd4:  idx_to_n_digit = 4'd1;
                5'd5,  5'd6,  5'd7,  5'd8,  5'd9:  idx_to_n_digit = 4'd2;
                5'd10, 5'd11, 5'd12, 5'd13, 5'd14: idx_to_n_digit = 4'd3;
                5'd15, 5'd16, 5'd17, 5'd18, 5'd19: idx_to_n_digit = 4'd4;
                default:                             idx_to_n_digit = 4'd5; // 20..24
            endcase
        end
    endfunction

    // Convert total_count to (h,t,o) without expensive division (bounded loop).
    function automatic [11:0] to_dec3;
        input [7:0] v;
        integer j;
        reg [3:0] h;
        reg [3:0] t;
        reg [3:0] o;
        reg [7:0] rem;
        begin
            h = 4'd0;
            t = 4'd0;
            o = 4'd0;
            rem = v;
            if (rem >= 8'd100) begin
                h = 4'd1;
                rem = rem - 8'd100;
            end
            for (j = 0; j < 13; j = j + 1) begin
                if (rem >= 8'd10) begin
                    t = t + 1'b1;
                    rem = rem - 8'd10;
                end
            end
            o = rem[3:0];
            to_dec3 = {h,t,o};
        end
    endfunction

    // FSM
    localparam ST_IDLE      = 3'd0;
    localparam ST_SCAN_SET  = 3'd1;
    localparam ST_SCAN_WAIT = 3'd2;
    localparam ST_SCAN_CAP  = 3'd3;
    localparam ST_SEND_LOAD = 3'd4;
    localparam ST_SEND_KICK = 3'd5;
    localparam ST_SEND_WAIT = 3'd6;

    reg [2:0] state;

    assign busy = (state != ST_IDLE);

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= ST_IDLE;
            dimX        <= 8'd1;
            dimY        <= 8'd1;
            scan_active <= 1'b0;

            scan_idx    <= 5'd0;
            scan_wait   <= 2'd0;
            total_count <= 8'd0;
            total_h     <= 4'd0;
            total_t     <= 4'd0;
            total_o     <= 4'd0;

            send_idx    <= 5'd0;
            item_phase  <= 3'd0;
            total_len   <= 2'd1;
            total_stage <= 2'd0;

            txStart     <= 1'b0;
            txData      <= 8'h00;

            for (i = 0; i < MAX_DIMS; i = i + 1) begin
                cnt_mem[i] <= 3'd0;
            end
        end else begin
            txStart <= 1'b0;

            case (state)
                ST_IDLE: begin
                    scan_active <= 1'b0;
                    if (start_pulse) begin
                        // init
                        scan_idx    <= 5'd0;
                        scan_wait   <= 2'd0;
                        total_count <= 8'd0;
                        send_idx    <= 5'd0;
                        item_phase  <= 3'd0;
                        total_len   <= 2'd1;
                        total_stage <= 2'd0;
                        for (i = 0; i < MAX_DIMS; i = i + 1) begin
                            cnt_mem[i] <= 3'd0;
                        end
                        state       <= ST_SCAN_SET;
                    end
                end

                ST_SCAN_SET: begin
                    scan_active <= 1'b1;
                    dimX <= {4'd0, idx_to_m_digit(scan_idx)};
                    dimY <= {4'd0, idx_to_n_digit(scan_idx)};
                    scan_wait <= 2'd0;
                    state <= ST_SCAN_WAIT;
                end

                ST_SCAN_WAIT: begin
                    // Wait a couple cycles for matrixIO to update fillState/readData
                    if (scan_wait < 2'd2) begin
                        scan_wait <= scan_wait + 1'b1;
                    end else begin
                        state <= ST_SCAN_CAP;
                    end
                end

                ST_SCAN_CAP: begin
                    cnt_mem[scan_idx] <= count;
                    total_count <= total_count + {5'd0, count};

                    if (scan_idx == 5'd24) begin
                        // done scanning
                        scan_active <= 1'b0;
                        {total_h, total_t, total_o} <= total_dec_next;
                        // Decide how many digits to send for total
                        if (total_dec_next[11:8] != 4'd0) begin
                            total_len <= 2'd3;
                        end else if (total_dec_next[7:4] != 4'd0) begin
                            total_len <= 2'd2;
                        end else begin
                            total_len <= 2'd1;
                        end
                        total_stage <= 2'd0;
                        send_idx    <= 5'd0;
                        item_phase  <= 3'd0;
                        state      <= ST_SEND_LOAD;
                    end else begin
                        scan_idx <= scan_idx + 1'b1;
                        state <= ST_SCAN_SET;
                    end
                end

                // SEND phases:
                ST_SEND_LOAD: begin
                    if (!txBusy) begin
                        // 1) Send total count digits (no leading zeros)
                        if (total_stage < total_len) begin
                            if (total_len == 2'd3) begin
                                if (total_stage == 2'd0) txData <= digit_ascii(total_h);
                                else if (total_stage == 2'd1) txData <= digit_ascii(total_t);
                                else txData <= digit_ascii(total_o);
                            end else if (total_len == 2'd2) begin
                                if (total_stage == 2'd0) txData <= digit_ascii(total_t);
                                else txData <= digit_ascii(total_o);
                            end else begin
                                txData <= digit_ascii(total_o);
                            end
                            state <= ST_SEND_KICK;
                        end else begin
                            // 2) Send each nonzero spec: " m*n*x"
                            // Find next nonzero count
                            if (send_idx < 5'd25 && cnt_mem[send_idx] == 3'd0) begin
                                send_idx <= send_idx + 1'b1;
                            end else if (send_idx >= 5'd25) begin
                                // 3) Done -> newline
                                txData <= 8'h0A;
                                state <= ST_SEND_KICK;
                            end else begin
                                // Emit current item byte-by-byte
                                case (item_phase)
                                    3'd0: txData <= 8'h20; // space
                                    3'd1: txData <= digit_ascii(idx_to_m_digit(send_idx));
                                    3'd2: txData <= 8'h2A; // '*'
                                    3'd3: txData <= digit_ascii(idx_to_n_digit(send_idx));
                                    3'd4: txData <= 8'h2A; // '*'
                                    default: txData <= digit_ascii({1'b0, cnt_mem[send_idx]});
                                endcase
                                state <= ST_SEND_KICK;
                            end
                        end
                    end
                end

                ST_SEND_KICK: begin
                    if (!txBusy) begin
                        txStart <= 1'b1;
                        state <= ST_SEND_WAIT;
                    end
                end

                ST_SEND_WAIT: begin
                    if (!txBusy) begin
                        // Advance total digits
                        if (total_stage < total_len) begin
                            total_stage <= total_stage + 1'b1;
                            state <= ST_SEND_LOAD;
                        end else if (send_idx >= 5'd25) begin
                            // we just sent newline
                            state <= ST_IDLE;
                        end else if (cnt_mem[send_idx] == 3'd0) begin
                            // keep searching
                            state <= ST_SEND_LOAD;
                        end else begin
                            // Advance within current item
                            if (item_phase < 3'd5) begin
                                item_phase <= item_phase + 1'b1;
                            end else begin
                                // finished this item (count digit)
                                item_phase <= 3'd0;
                                send_idx   <= send_idx + 1'b1;
                            end
                            state <= ST_SEND_LOAD;
                        end
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
