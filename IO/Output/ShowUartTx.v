`timescale 1ns / 1ps

module ShowUartTx #(
    parameter NUM_DIGHT   = 32,
    parameter CLK_FREQ_HZ = 100_000_000,
    parameter BAUD_RATE   = 115200
) (
    input  wire       clk,
    input             uartTxRstN,
    input             sendOne,
    input             promptStart,
    input  wire [1:0] promptSel,
    input  wire [199:0] matrixData,
    input  wire [7:0] m,
    input  wire [7:0] n,
    input  wire [7:0] id,
    input             ifID,
    input             ifNM,
    output wire       uartTx,
    output wire       busy
);

    // -----------------------------------------------------------
    // 1. 信号边沿检测 (和参考代码一致)
    // -----------------------------------------------------------
    reg sendOneD1, sendOneD2;
    reg promptD1, promptD2;
    always @(posedge clk or negedge uartTxRstN) begin
        if(!uartTxRstN) begin
            sendOneD1 <= 1'b0;
            sendOneD2 <= 1'b0;
            promptD1  <= 1'b0;
            promptD2  <= 1'b0;
        end else begin
            sendOneD1 <= sendOne;
            sendOneD2 <= sendOneD1;
            promptD1  <= promptStart;
            promptD2  <= promptD1;
        end
    end
    wire sendFlag   = sendOneD1 & ~sendOneD2;
    wire promptFlag = promptD1  & ~promptD2;

    // -----------------------------------------------------------
    // 2. 提示字符辅助函数 (保留原逻辑)
    // -----------------------------------------------------------
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

    // -----------------------------------------------------------
    // 3. 模块实例化
    // -----------------------------------------------------------
    reg asciiStart;
    reg [7:0] key;
    wire [31:0] txData; // BinaryToASCII 输出是32位 (4字节)
    reg [31:0] num;
    wire asciiDone, asciiBusy;

    BinaryToASCII asciiNum(
        .clk(clk),
        .rstN(uartTxRstN),
        .ifStart(asciiStart),
        .binaryNum(key),
        .asciiNum(txData),
        .ifDone(asciiDone),
        .ifBusy(asciiBusy)
    );

    reg txStart;
    reg [7:0] txDt;
    wire txDataBusy;
    
    UartTx #(
        .CLK_FREQ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) uartTxData(
        .clk(clk),
        .rstN(uartTxRstN),
        .txStart(txStart),
        .txData(txDt),
        .tx(uartTx),
        .txBusy(txDataBusy)
    );

    // -----------------------------------------------------------
    // 4. 主状态机 (完全仿照 InfoUartTx 结构)
    // -----------------------------------------------------------
    reg isWait, isStart, txBusy;
    reg isPrompt;         // 标记：当前是否在发提示符
    reg [2:0] flowStep;   // 流程步骤: 0=ID, 1=M, 2=N, 3=MATRIX
    reg [2:0] ix, iy;     // 矩阵坐标
    reg [3:0] byteIdx;    // 字节发送计数器 (替代参考代码中的 idy)
    reg [3:0] promptIdx;  // 提示符字符计数
    reg [1:0] promptSelReg;

    assign busy = txBusy;

    always @(posedge clk or negedge uartTxRstN) begin
        if(!uartTxRstN) begin
            // 复位所有状态
            txBusy       <= 1'b0;
            isWait       <= 1'b0;
            isStart      <= 1'b0;
            asciiStart   <= 1'b0;
            txStart      <= 1'b0;
            
            isPrompt     <= 1'b0;
            promptIdx    <= 4'd0;
            promptSelReg <= 2'd0;
            
            flowStep     <= 3'd0;
            ix           <= 3'd0;
            iy           <= 3'd0;
            byteIdx      <= 4'd0;
            key          <= 8'd0;
            num          <= 32'd0;
        end 
        else if(promptFlag && !txBusy) begin
            // 收到 Prompt 请求
            txBusy       <= 1'b1;
            isPrompt     <= 1'b1;
            promptIdx    <= 4'd0;
            promptSelReg <= promptSel;
            
            // 确保其他标志位复位
            isWait       <= 1'b0;
            isStart      <= 1'b0;
            txStart      <= 1'b0;
        end
        else if(sendFlag && !txBusy) begin
            // 收到 SendOne 请求
            txBusy       <= 1'b1;
            isPrompt     <= 1'b0;
            
            // 初始化数据发送流程
            flowStep     <= 3'd0; // 从 ID 开始检查
            ix           <= 3'd0;
            iy           <= 3'd0;
            
            isWait       <= 1'b0;
            isStart      <= 1'b0;
            asciiStart   <= 1'b0;
            txStart      <= 1'b0;
        end 
        else if(txBusy) begin
            // ================= 忙碌状态处理 =================
            
            if(isPrompt) begin
                // ---------------- 模式 A: 发送提示符 ----------------
                if(txDataBusy && txStart) begin
                    txStart <= 1'b0; // 握手：清除Start
                end else if(!txDataBusy && !txStart) begin
                    txDt    <= prompt_char(promptSelReg, promptIdx);
                    txStart <= 1'b1;
                    if(promptIdx + 1'b1 < prompt_len(promptSelReg)) begin
                        promptIdx <= promptIdx + 1'b1;
                    end else begin
                        isPrompt <= 1'b0;
                        txBusy   <= 1'b0; // 提示符发送完毕，释放总线
                    end
                end
            end 
            else begin
                // ---------------- 模式 B: 发送数据 (ID, M, N, Matrix) ----------------
                
                // 1. 准备数据并启动转换
                // 参考代码逻辑：if(!isWait) { 准备key; 启动asciiStart; isWait=1; }
                if(!isWait) begin
                    // 根据 flowStep 决定发什么
                    // 这里利用组合逻辑的思维，但在时序逻辑中赋值，确保 key 稳定
                    case(flowStep)
                        3'd0: begin // ID 阶段
                            if(ifID) begin
                                key <= id;
                                asciiStart <= 1'b1;
                                isWait <= 1'b1;
                                isStart <= 1'b0;
                            end else begin
                                flowStep <= 3'd1; // 跳过 ID，去 M
                            end
                        end
                        3'd1: begin // M 阶段
                            if(ifNM) begin
                                key <= m;
                                asciiStart <= 1'b1;
                                isWait <= 1'b1;
                                isStart <= 1'b0;
                            end else begin
                                flowStep <= 3'd3; // 跳过 NM，直接去 Matrix
                            end
                        end
                        3'd2: begin // N 阶段
                            if(ifNM) begin
                                key <= n;
                                asciiStart <= 1'b1;
                                isWait <= 1'b1;
                                isStart <= 1'b0;
                            end else begin
                                flowStep <= 3'd3;
                            end
                        end
                        3'd3: begin // Matrix 阶段
                            if(iy < m) begin
                                // 提取矩阵数据
                                key <= (matrixData >> ((iy * n + ix) * 8)) & 8'hFF;
                                asciiStart <= 1'b1;
                                isWait <= 1'b1;
                                isStart <= 1'b0;
                            end else begin
                                // 矩阵发送完毕，任务结束
                                txBusy <= 1'b0; 
                            end
                        end
                    endcase
                end 
                
                // 2. 等待 ASCII 模块忙信号拉高 (握手)
                else if(!isStart && asciiBusy) begin
                    asciiStart <= 1'b0; // 撤销启动信号
                end 
                
                // 3. 等待 ASCII 转换完成
                else if(!isStart && asciiDone) begin
                    isStart <= 1'b1;    // 进入发送阶段
                    num     <= txData;  // 锁存转换结果
                    byteIdx <= 4'd0;    // 重置字节计数
                    txStart <= 1'b0;
                end 
                
                // 4. 发送转换好的数据 (通过 UART)
                else if(isStart) begin
                    if(txDataBusy && txStart) begin
                        txStart <= 1'b0;
                    end else if(!txDataBusy && !txStart) begin
                        // 逻辑：发送 4个ASCII字节 + 1个分隔符 (共5步)
                        if(byteIdx < 4) begin
                            case(byteIdx)
                                4'd0: txDt <= num[31:24];
                                4'd1: txDt <= num[23:16];
                                4'd2: txDt <= num[15:8];
                                4'd3: txDt <= num[7:0];
                            endcase
                            txStart <= 1'b1;
                            byteIdx <= byteIdx + 1'b1;
                        end 
                        else if(byteIdx == 4) begin
                            // 发送分隔符 (换行或空格)
                            case(flowStep)
                                3'd0: txDt <= 8'h0A; // ID 后换行
                                3'd1: txDt <= 8'h20; // M 后空格
                                3'd2: txDt <= 8'h0A; // N 后换行
                                3'd3: begin          // Matrix 元素后
                                    if(ix == n - 1) txDt <= 8'h0A; // 行末换行
                                    else            txDt <= 8'h20; // 元素间空格
                                end
                                default: txDt <= 8'h20;
                            endcase
                            txStart <= 1'b1;
                            byteIdx <= byteIdx + 1'b1;
                        end 
                        else begin
                            // 当前数值发送完毕 (5字节全发完了)
                            isWait  <= 1'b0;
                            isStart <= 1'b0; // 回到准备数据阶段
                            
                            // 更新步骤或坐标
                            case(flowStep)
                                3'd0: flowStep <= 3'd1; // ID -> M
                                3'd1: flowStep <= 3'd2; // M -> N
                                3'd2: flowStep <= 3'd3; // N -> Matrix
                                3'd3: begin
                                    // 更新矩阵坐标
                                    if(ix < n - 1) begin
                                        ix <= ix + 1'b1;
                                    end else begin
                                        ix <= 3'd0;
                                        iy <= iy + 1'b1;
                                        // 注意：这里只负责坐标加1，
                                        // 真正的结束判断在 if(!isWait) 的 case 3'd3 里
                                    end
                                end
                            endcase
                        end
                    end
                end
            end
        end
    end

endmodule