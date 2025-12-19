package com.fpga.ui;

import com.fpga.core.SerialService;
import javafx.fxml.FXML;
import javafx.scene.control.Label;
import javafx.scene.control.TextField;

public class RandomModeController {

    @FXML private TextField xInput;
    @FXML private TextField yInput;
    @FXML private Label logLabel;

    @FXML
    private void onSendX() {
        String val = xInput.getText();
        if (!val.isEmpty()) {
            SerialService.getInstance().send(val);
            logLabel.setText("Sent X dimension: " + val);
            logLabel.setStyle("-fx-text-fill: #a6e3a1;");
        }
    }

    @FXML
    private void onSendY() {
        String val = yInput.getText();
        if (!val.isEmpty()) {
            SerialService.getInstance().send(val);
            logLabel.setText("Sent Y dimension: " + val + ". FPGA Generating...");
            logLabel.setStyle("-fx-text-fill: #a6e3a1;");
        }
    }
}