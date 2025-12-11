`timescale 1ns / 1ps

module ModeUartNotifier #(
    parameter integer CLK_FREQ_HZ = 100_000_000, // match board clock; wrong value causes garbled UART
    parameter integer BAUD_RATE   = 115200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [2:0] mode_state,
    output wire       uart_tx,
    output wire       busy
);
    // Mode enumeration
    localparam MODE_DEFAULT = 3'd0;
    localparam MODE_STORE   = 3'd1;
    localparam MODE_GEN     = 3'd2;
    localparam MODE_SHOW    = 3'd3;
    localparam MODE_CALC    = 3'd4;
    localparam MODE_SETUP   = 3'd5;

    // --- 1. 函数定义 ---

    // Map mode to message length (bytes, includes trailing \n)
    function automatic [3:0] mode_msg_len;
        input [2:0] mode;
        begin
            case (mode)
                MODE_STORE: mode_msg_len = 4'd6; // "STORE\n"
                MODE_GEN:   mode_msg_len = 4'd4; // "GEN\n"
                MODE_SHOW:  mode_msg_len = 4'd5; // "SHOW\n"
                MODE_CALC:  mode_msg_len = 4'd5; // "CALC\n"
                MODE_SETUP: mode_msg_len = 4'd6; // "SETUP\n"
                default:    mode_msg_len = 4'd8; // "DEFAULT\n"
            endcase
        end
    endfunction

    // Map mode + index -> ASCII byte
    // 修复了此处原代码缺失的函数体
    function automatic [7:0] mode_msg_char;
        input [2:0] mode;
        input [3:0] idx;
        begin
            case (mode)
                MODE_STORE: begin // "STORE\n"
                    case(idx)
                        0: mode_msg_char = "S"; 1: mode_msg_char = "T"; 2: mode_msg_char = "O";
                        3: mode_msg_char = "R"; 4: mode_msg_char = "E"; default: mode_msg_char = "\n";
                    endcase
                end
                MODE_GEN: begin // "GEN\n"
                    case(idx)
                        0: mode_msg_char = "G"; 1: mode_msg_char = "E"; 2: mode_msg_char = "N";
                        default: mode_msg_char = "\n";
                    endcase
                end
                MODE_SHOW: begin // "SHOW\n"
                    case(idx)
                        0: mode_msg_char = "S"; 1: mode_msg_char = "H"; 2: mode_msg_char = "O";
                        3: mode_msg_char = "W"; default: mode_msg_char = "\n";
                    endcase
                end
                MODE_CALC: begin // "CALC\n"
                    case(idx)
                        0: mode_msg_char = "C"; 1: mode_msg_char = "A"; 2: mode_msg_char = "L";
                        3: mode_msg_char = "C"; default: mode_msg_char = "\n";
                    endcase
                end
                MODE_SETUP: begin // "SETUP\n"
                    case(idx)
                        0: mode_msg_char = "S"; 1: mode_msg_char = "E"; 2: mode_msg_char = "T";
                        3: mode_msg_char = "U"; 4: mode_msg_char = "P"; default: mode_msg_char = "\n";
                    endcase
                end
                default: begin // "DEFAULT\n"
                    case(idx)
                        0: mode_msg_char = "D"; 1: mode_msg_char = "E"; 2: mode_msg_char = "F";
                        3: mode_msg_char = "A"; 4: mode_msg_char = "U"; 5: mode_msg_char = "L"; 6: mode_msg_char = "T";
                        default: mode_msg_char = "\n";
                    endcase
                end
            endcase
        end
    endfunction

    // --- 2. 信号声明 ---

    reg  [2:0] mode_state_d; // 上一拍模式，用于检测边沿
    reg        pending_req;  // 有待发送的请求
    reg  [2:0] pending_mode; // 待发送模式
    
    // FSM Signals
    reg  [1:0] state;
    reg  [2:0] send_mode;
    reg  [3:0] send_idx;
    
    // UART Interface
    reg        txStart;
    reg  [7:0] txData;
    wire       txBusy;

    // Post-reset idle to avoid truncated frame/glitch when rst_n is pressed mid-frame
    localparam integer RESET_IDLE_CYCLES = (CLK_FREQ_HZ / BAUD_RATE) * 2; // >= 2 bit periods
    reg [31:0] reset_cnt;
    reg        in_reset_guard;

    localparam ST_IDLE  = 2'd0;
    localparam ST_LOAD  = 2'd1;
    localparam ST_KICK  = 2'd2;
    localparam ST_WAIT  = 2'd3;

    assign busy = (state != ST_IDLE) || pending_req || in_reset_guard;

    // --- 3. 边缘检测逻辑 ---
    
    // Queue a send whenever mode changes; also queue DEFAULT after reset release
    // with a short idle guard to avoid mid-frame reset producing garbage bytes.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mode_state_d   <= MODE_DEFAULT;
            pending_req    <= 1'b0;       // hold off during reset assertion
            pending_mode   <= MODE_DEFAULT;
            reset_cnt      <= RESET_IDLE_CYCLES[31:0];
            in_reset_guard <= 1'b1;
        end else begin
            if (in_reset_guard) begin
                mode_state_d <= MODE_DEFAULT; // freeze detection during guard
                if (reset_cnt != 0) begin
                    reset_cnt <= reset_cnt - 1'b1;
                end else begin
                    in_reset_guard <= 1'b0;
                    pending_req    <= 1'b1;      // now send DEFAULT once
                    pending_mode   <= MODE_DEFAULT;
                end
            end else begin
                mode_state_d <= mode_state;

                // 模式变化：记录最新模式并置位请求
                if (mode_state != mode_state_d) begin
                    pending_req  <= 1'b1;
                    pending_mode <= mode_state;
                end
                // 状态机在空闲态接收请求后，握手清除请求
                else if (state == ST_IDLE && pending_req) begin
                    pending_req <= 1'b0;
                end
            end
        end
    end

    // --- 4. 状态机逻辑 (发送控制器) ---

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= ST_IDLE;
            send_mode <= MODE_DEFAULT;
            send_idx  <= 4'd0;
            txStart   <= 1'b0;
            txData    <= 8'h00;
        end else begin
            // Default pulse low
            txStart <= 1'b0; 

            case (state)
                ST_IDLE: begin
                    send_idx <= 4'd0;
                    if (pending_req) begin
                        send_mode <= pending_mode;
                        state     <= ST_LOAD;
                    end
                end

                ST_LOAD: begin
                    // 先装载数据，下一拍再拉 txStart，确保 UartTx 采样到正确的 txData
                    if (!txBusy) begin
                        txData <= mode_msg_char(send_mode, send_idx);
                        state  <= ST_KICK;
                    end
                end

                ST_KICK: begin
                    if (!txBusy) begin
                        txStart <= 1'b1; // txData 已经稳定一拍
                        state   <= ST_WAIT;
                    end
                end

                ST_WAIT: begin
                    if (!txBusy) begin
                        if (send_idx + 1'b1 < mode_msg_len(send_mode)) begin
                            send_idx <= send_idx + 1'b1;
                            state    <= ST_LOAD;
                        end else begin
                            state <= ST_IDLE;
                        end
                    end else begin
                        state <= ST_WAIT; // 等待发送完成
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

    // --- 5. 模块实例化 ---

    UartTx #(
        .CLK_FREQ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) u_uart_tx (
        .clk(clk),
        .rstN(rst_n),
        .txStart(txStart),
        .txData(txData),
        .tx(uart_tx),
        .txBusy(txBusy)
    );

endmodule