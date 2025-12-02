

# 架构设计文档

项楚涵 郭一笑 刘君昊

## Part 1. 项目中使用的输入/输出设备

![微信图片_20251129174145_108_252](C:\Users\LENOVO\Desktop\Digit_Logic\微信图片_20251129174145_108_252.jpg)

### 输入设备

1.  **UART RX**
    *   **功能：** 系统主要的数据输入接口。用于接收 PC 端软件（串口调试助手）发送的矩阵维度信息、矩阵元素数值以及操作指令。
2.  **拨码开关**
    *   **功能：** 用于硬件模式选择和参数设置。
    *   **SW[7:3]：**设置系统的工作模式
    *   **SW[7:3]：**选择具体的运算类型（矩阵转置、矩阵加法、标量乘法、矩阵乘法、卷积）
    *   **SW[7:4]：** 用于在“标量乘法”模式下，输入标量的值 (0-9)。
3.  **按键开关**
    *   **S1 (确认键)：** 作为“Enter”键使用，用于确认模式选择、确认运算数维度输入或确认标量输入。
    *   **S2 (复位键)：** 系统全局复位。

### 输出设备 (Output Devices)

1.  **UART TX**
    *   **功能：** 系统主要的显示/反馈接口。将存储的矩阵数据、运算结果、错误提示及菜单信息回传至 PC 端的串口助手窗口进行展示。
2.  **LED 指示灯:**
    *   **功能：** 错误报警指示。当检测到用户输入的维度非法（超出范围）或运算不合法（例如加法时两矩阵维度不匹配）时点亮。
3.  **7段数码管 (7-Segment Display):**
    *   **功能：** 用于显示当前状态代码和倒计时。
    *   **数码管 [0:2] (最左侧)：** 显示当前选中的运算类型字符（'ADD' 代表加法，'MUL' 代表乘法，'TRA' 代表转置，'CON' 代表卷积）。
    *   **数码管 [7:8] (最右侧)：** 在发生错误时显示倒计时（默认 10 秒），倒计时结束若未修正输入则重置选择。

## Part 2. 项目架构描述

### 1. 电路结构框图

如果 module 内的临时寄存器是其子 module 的输入，将不表出。

对于一些重复且大量的输入/输出，不一定直接表明，可能统一标在了更外面的模块上。

大概的电路结构框架图如下：

![update_part2](C:\Users\LENOVO\Desktop\OneDrive\update_part2.png)

### 2. 模块功能说明表

| 模块名称 (Module Name) | 输入端口 (Input Ports)                                       | 输出端口 (Output Ports)                                      | 功能描述 (Function)                                          |
| ---------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ | ------------------------------------------------------------ |
| UartRx                 | rx, clk                                                      | rxData[7:0], rxDone                                          | 接收来自 PC 端串口的单个字符。                               |
| UartRxAll              | rx, clk, uartRxRstN                                          | inputData[215:0], len[4:0]                                   | 接收来自 PC 端串口的字节流，用于矩阵维度、元素等。           |
| Verify                 | rx, clk, order[2:0], ifGet, rangeCfg, maxMatrixPerSize, countdownCfg | n[7:0], m[7:0], count[7:0], Matrix[199:0], led, rxDone       | 判断输入是否合法                                             |
| SwRx                   | sw, num[3:0]                                                 | val[3:0]                                                     | 接收来自开关的输入数据                                       |
| SettingsControl        | sw, key, reset                                               | rangeCfg, maxMatrixPerSize, countdownCfg                     | 动态配置系统参数：元素范围、最大存储数量、倒计时时长等。     |
| CountdownTimer         | start, clk, countdownCfg, reset                              | countVal[4:0], timeout                                       | 输入错误时启动倒计时，并输出当前倒计时值至数码管。           |
| MatrixStorage          | clk, storeEn, matrixData[199:0], m[7:0], n[7:0]              | matrixA[199:0], matrixB[199:0],  MatrixListInfo[57:0]        | RAM 存储矩阵，支持覆盖策略与编号管理，供运算与显示模块读取。 |
| RandomGenerator        | clk, enable                                                  | randNum                                                      | 在矩阵随机生成模式下提供伪随机数作为矩阵元素。               |
| TransposeUnit          | clk, reset, matrixA[199:0]                                   | matrixAT[199:0], valid                                       | 实现矩阵转置运算。                                           |
| AddUnit                | clk, reset, matrixA[199:0], matrixB[199:0]                   | aPlusB[199:0], valid, addError                               | 实现矩阵加法运算                                             |
| ScalarMultiplyUnit     | clk, reset, matrixA[199:0], scalarValue[3:0]                 | scalarMul[199:0], valid                                      | 实现矩阵与标量相乘运算                                       |
| MatrixMultiplyUnit     | clk, reset, matrixA[199:0], matrixB[199:0]                   | aMulB[199:0], valid, mulError                                | 实现矩阵乘法运算                                             |
| ConvolutionUnit        | inputImage, kernelMatrix[35:0], clk, reset                   | convResult[255:0], valid, cycleCount[9:0], done              | 对 10×12 输入图像执行 3×3 卷积（bonus）进行运算。            |
| UartTx                 | clk, rstN,txStart,txData[7:0]                                | tx,txBusy                                                    | 将单个字符输出到PC端串口                                     |
| MatrixUartTx           | clk, matrixData[199:0], n, m, ifClear, id, uartTxRstN, ifSend | tx                                                           | 将矩阵元素进行处理使之输出到 PC 端串口助手时符合格式。       |
| InfoUartTx             | clk, count[57:0], uartTxRstN, ifSend                         | tx                                                           | 将矩阵总数、矩阵规格列表等进行处理使之输出到 PC 端串口助手时符合格式。 |
| SevenSegDisplay        | modeSelect, opType[1:0], countVal[4:0]                       | segOp[20:0], segCt[13:0]                                     | 显示运算类型或倒计时时间。                                   |
| Default                | clk, rx, uartRxRstN, uartTxRstN, mode[4:0], type[4:0], num[3:0], s1, s2 | led, tx, segOp[20:0], segCt[13:0]                            | Top module                                                   |
| SettingMode            | clk, rx, uartRxRstN                                          | rangeCfg, maxMatrixPerSize, countdownCfg                     | 设置系统参数功能                                             |
| StoreMode              | clk, rx, uartRxRstN, enable, rangeCfg, maxMatrixPerSize, countdownCfg | storeEn, matrixData[199:0], m[7:0], n[7:0], led              | 矩阵输入及储存功能                                           |
| GeneratorMode          | clk, rx, uartRxRstN, enable, rangeCfg, maxMatrixPerSize, countdownCfg | storeEn, matrixData[199:0], m[7:0], n[7:0], led              | 矩阵生成及储存功能                                           |
| ShowMode               | clk, rx, uartRxRstN, uartTxRstN, enable, rangeCfg, maxMatrixPerSize, countdownCfg, matrixA[199:0], matrixB[199:0],  MatrixListInfo [57:0] | storeEn, matrixData[199:0], m[7:0], n[7:0], led, tx          | 矩阵展示功能                                                 |
| CalculateMode          | clk, rx, uartRxRstN, uartTxRstN, enable, rangeCfg, maxMatrixPerSize, countdownCfg, matrixA[199:0], matrixB[199:0],  MatrixListInfo [57:0], type[4:0], num[3:0], s1 | storeEn, matrixData[199:0], m[7:0], n[7:0], led, tx, segOp[20:0], segCt[13:0] | 矩阵运算功能                                                 |
| Transpose              | clk, rx, uartRxRstN, uartTxRstN, enable, rangeCfg, maxMatrixPerSize, countdownCfg, matrixA[199:0], matrixB[199:0],  MatrixListInfo [57:0] | storeEn, matrixData[199:0], m[7:0], n[7:0], led, tx          | 实现矩阵转置                                                 |
| Add                    | clk, rx, uartRxRstN, uartTxRstN, enable, rangeCfg, maxMatrixPerSize, countdownCfg, matrixA[199:0], matrixB[199:0],  MatrixListInfo [57:0] | storeEn, matrixData[199:0], m[7:0], n[7:0], led, tx, segOp[20:0], segCt[13:0] | 实现矩阵加法；检测维度一致性。                               |
| ScalarMultiply         | clk, rx, uartRxRstN, uartTxRstN, enable, rangeCfg, maxMatrixPerSize, countdownCfg, matrixA[199:0], matrixB[199:0],  MatrixListInfo [57:0], num[3:0], s1 | storeEn, matrixData[199:0], m[7:0], n[7:0], led, tx, segOp[20:0], segCt[13:0] | 实现矩阵与标量相乘                                           |
| MatrixMultiply         | clk, rx, uartRxRstN, uartTxRstN, enable, rangeCfg, maxMatrixPerSize, countdownCfg, matrixA[199:0], matrixB[199:0],  MatrixListInfo [57:0] | storeEn, matrixData[199:0], m[7:0], n[7:0], led, tx, segOp[20:0], segCt[13:0] | 实现矩阵乘法，检查内部维度是否匹配。                         |
| Convolution            | clk, rx, uartRxRstN, uartTxRstN, enable, rangeCfg, maxMatrixPerSize, countdownCfg, matrixA[199:0], matrixB[199:0],  MatrixListInfo [57:0] | storeEn, matrixData[199:0], m[7:0], n[7:0], led, tx          | 实现卷积                                                     |
| getCal1                | clk, rx, uartRxRstN, uartTxRstN, rangeCfg, maxMatrixPerSize, countdownCfg, matrixA[199:0], matrixB[199:0],  MatrixListInfo [57:0] | matrixA[199:0], led, tx                                      | 手动选择一个运算数                                           |
| getMatrix              | clk, rx, uartRxRstN, uartTxRstN, enable, rangeCfg, maxMatrixPerSize, countdownCfg, matrixA[199:0], matrixB[199:0],  MatrixListInfo [57:0] | matrixA[199:0], matrixB[199:0], sotreEn, led, tx             | 得到运算数                                                   |
| getCal2                | clk, rx, uartRxRstN, uartTxRstN, rangeCfg, maxMatrixPerSize, countdownCfg, matrixA[199:0], matrixB[199:0],  MatrixListInfo [57:0] | matrixA[199:0], matrixB[199:0], led, tx                      | 手动选择两个运算数                                           |
| RandomGetMatrix        | clk, enable, MatrixListInfo [57:0]                           | matrixA[199:0], matrixB[199:0], sotreEn, led, tx             | 随机选择运算数                                               |
| Checker                | clk, rx, uartRxRstN, uartTxRstN, rangeCfg, maxMatrixPerSize, countdownCfg, matrixA[199:0], matrixB[199:0],  MatrixListInfo [57:0] | storeEn, matrixA[199:0], matrixB[199:0], led, tx, segOp[20:0], segCt[13:0] | 检查两个运算符的运算是否合法                                 |

## Part 3. 项目有限状态机

### 1. 状态列表

系统主要包含以下状态：

1.  **空闲状态** 等待用户设置拨码开关并按下“确认键”。
2.  **设置：等待输入变量类型** 
3.  **设置：等待输入设置值** 
4.  **生成矩阵：等待输入**
5.  **存储矩阵：等待输入维度**
6.  **存储矩阵：等待输入类型**
7.  **矩阵展示：等待输入**
8.  **矩阵计算：等待输入维度**
9.  **矩阵计算：等待输入编号**
10.  **矩阵计算：错误倒计时**
11.  **矩阵计算：等待计算完毕**

### 2. 状态流转图描述 (State Transition Diagram Description)

![微信图片_20251129222328_121_252](C:\Users\LENOVO\Desktop\Digit_Logic\微信图片_20251129222328_121_252.png)