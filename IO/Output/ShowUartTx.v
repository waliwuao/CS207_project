`timescale 1ns / 1ps

module ShowUartTx #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 115200
)(
    input  wire       clk,
    input             uartTxRstN,
    input             sendOne,      // kept for interface compatibility; ignored
    input             promptStart,
    input  wire [1:0] promptSel,
    output wire       uartTx,
    output wire       busy
);

    // -----------------------------
    // Prompt helpers (string only)
    // -----------------------------
    localparam PROMPT_WAIT1   = 2'd0;
    localparam PROMPT_WAIT2   = 2'd1;
    localparam PROMPT_DISPLAY = 2'd2;

    function automatic [3:0] prompt_len;
        input [1:0] s;
        begin
            case (s)
                PROMPT_WAIT1:   prompt_len = 4'd6; // wait1\n
                PROMPT_WAIT2:   prompt_len = 4'd6; // wait2\n
                PROMPT_DISPLAY: prompt_len = 4'd8; // display\n
                default:        prompt_len = 4'd1;
            endcase
        end
    endfunction

    function automatic [7:0] prompt_char;
        input [1:0] s;
        input [3:0] idx;
        begin
            case (s)
                PROMPT_WAIT1: begin
                    case (idx)
                        0: prompt_char = "w"; 1: prompt_char = "a"; 2: prompt_char = "i";
                        3: prompt_char = "t"; 4: prompt_char = "1"; default: prompt_char = "\n";
                    endcase
                end
                PROMPT_WAIT2: begin
                    case (idx)
                        0: prompt_char = "w"; 1: prompt_char = "a"; 2: prompt_char = "i";
                        3: prompt_char = "t"; 4: prompt_char = "2"; default: prompt_char = "\n";
                    endcase
                end
                default: begin 
                    case (idx)
                        0: prompt_char = "d"; 1: prompt_char = "i"; 2: prompt_char = "s";
                        3: prompt_char = "p"; 4: prompt_char = "l"; 5: prompt_char = "a";
                        6: prompt_char = "y"; default: prompt_char = "\n";
                    endcase
                end
            endcase
        end
    endfunction

    // -----------------------------
    // Edge detect for prompt start
    // -----------------------------
    reg prompt_d1, prompt_d2;
    always @(posedge clk or negedge uartTxRstN) begin
        if (!uartTxRstN) begin
            prompt_d1 <= 1'b0;
            prompt_d2 <= 1'b0;
        end else begin
            prompt_d1 <= promptStart;
            prompt_d2 <= prompt_d1;
        end
    end
    wire promptFlag = prompt_d1 & ~prompt_d2;

    // -----------------------------
    // UART datapath
    // -----------------------------
    reg       txStart;
    reg [7:0] txData;
    wire      txBusy;

    UartTx #(
        .CLK_FREQ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) u_uart_tx (
        .clk(clk),
        .rstN(uartTxRstN),
        .txStart(txStart),
        .txData(txData),
        .tx(uartTx),
        .txBusy(txBusy)
    );

    // -----------------------------
    // Simple prompt-only FSM
    // -----------------------------
    localparam ST_IDLE = 2'd0;
    localparam ST_LOAD = 2'd1;
    localparam ST_KICK = 2'd2;
    localparam ST_WAIT = 2'd3;

    reg [1:0] state;
    reg [1:0] active_prompt;
    reg [3:0] prompt_idx;

    assign busy = (state != ST_IDLE);

    always @(posedge clk or negedge uartTxRstN) begin
        if (!uartTxRstN) begin
            state          <= ST_IDLE;
            active_prompt  <= PROMPT_WAIT1;
            prompt_idx     <= 4'd0;
            txStart        <= 1'b0;
            txData         <= 8'h00;
        end else begin
            txStart <= 1'b0; // default low pulse

            case (state)
                ST_IDLE: begin
                    prompt_idx <= 4'd0;
                    if (promptFlag) begin
                        active_prompt <= promptSel;
                        state         <= ST_LOAD;
                    end
                end

                ST_LOAD: begin
                    if (!txBusy) begin
                        txData <= prompt_char(active_prompt, prompt_idx);
                        state  <= ST_KICK;
                    end
                end

                ST_KICK: begin
                    if (!txBusy) begin
                        txStart <= 1'b1;
                        state   <= ST_WAIT;
                    end
                end

                ST_WAIT: begin
                    if (!txBusy) begin
                        if (prompt_idx + 1'b1 < prompt_len(active_prompt)) begin
                            prompt_idx <= prompt_idx + 1'b1;
                            state      <= ST_LOAD;
                        end else begin
                            state <= ST_IDLE;
                        end
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule