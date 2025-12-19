package com.fpga.ui;

import com.fpga.core.SerialService;
import javafx.fxml.FXML;
import javafx.scene.control.TextArea;
import javafx.scene.control.TextField;

public class CalcModeController {

    @FXML private TextArea calcLog;
    @FXML private TextField inputField;

    @FXML
    public void initialize() {
        calcLog.appendText("\n> Calculation Mode Ready.\n> Please input operation commands.\n");
    }

    @FXML
    private void onSendCommand() {
        String cmd = inputField.getText();
        if (cmd != null && !cmd.isEmpty()) {
            // 发送数据到 FPGA
            SerialService.getInstance().send(cmd);

            // 更新 UI 日志
            calcLog.appendText("> Sent: " + cmd + "\n");

            // 清空输入框
            inputField.clear();
        }
    }

    // 如果后续需要显示从FPGA回传的计算结果，可以添加此方法供外部调用
    public void appendResult(String result) {
        calcLog.appendText("< FPGA: " + result + "\n");
    }
}