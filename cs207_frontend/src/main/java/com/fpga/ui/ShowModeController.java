package com.fpga.ui;

import com.fpga.core.SerialService;
import javafx.fxml.FXML;
import javafx.scene.control.TextArea;
import javafx.scene.control.TextField;

public class ShowModeController {
    @FXML private TextArea matrixOutput;
    @FXML private TextField inputField;

    @FXML
    public void initialize() {
        matrixOutput.appendText("\n> Mode Active. Please input dimensions on hardware or below.\n");
    }

    @FXML
    private void onSendCommand() {
        String cmd = inputField.getText();
        if (!cmd.isEmpty()) {
            SerialService.getInstance().send(cmd); // 发送给FPGA
            matrixOutput.appendText("> Sent: " + cmd + "\n");
            inputField.clear();
        }
    }
}