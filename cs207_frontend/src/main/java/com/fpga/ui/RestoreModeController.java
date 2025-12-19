package com.fpga.ui;

import com.fpga.core.SerialService;
import javafx.application.Platform;
import javafx.fxml.FXML;
import javafx.scene.control.Button;
import javafx.scene.control.Label;
import javafx.scene.control.TextField;
import javafx.scene.layout.GridPane;
import java.util.ArrayList;
import java.util.List;

public class RestoreModeController {

    @FXML private TextField xInput;
    @FXML private TextField yInput;

    // 修改：使用 GridPane 替代 TilePane
    @FXML private GridPane matrixGrid;

    @FXML private Button btnSendData;
    @FXML private Label statusLabel;

    private int dimRows = 0; // X
    private int dimCols = 0; // Y

    // 我们依然需要一个List来保存所有引用，方便最后发送数据时按顺序遍历
    private final List<TextField> matrixCells = new ArrayList<>();

    @FXML
    public void initialize() {
        // 初始化时清空
        statusLabel.setText("Please enter dimensions.");
    }

    @FXML
    private void onSendX() {
        String xVal = xInput.getText();
        if (isValidInt(xVal)) {
            SerialService.getInstance().send(xVal); // 发送给FPGA
            dimRows = Integer.parseInt(xVal);
            statusLabel.setText("Rows (X) set to " + dimRows);
        } else {
            statusLabel.setText("Invalid X value!");
        }
    }

    @FXML
    private void onSendY() {
        String yVal = yInput.getText();
        // 确保先设置了X，并且Y也是有效数字
        if (isValidInt(yVal) && dimRows > 0) {
            SerialService.getInstance().send(yVal); // 发送给FPGA
            dimCols = Integer.parseInt(yVal);
            statusLabel.setText("Matrix: " + dimRows + " (Rows) x " + dimCols + " (Cols)");

            // 生成矩阵网格 UI
            generateMatrixGrid(dimRows, dimCols);
            btnSendData.setDisable(false);
        } else {
            if(dimRows <= 0) statusLabel.setText("Please set X (Rows) first!");
            else statusLabel.setText("Invalid Y value!");
        }
    }

    /**
     * 核心修改：按行和列生成网格
     */
    private void generateMatrixGrid(int rows, int cols) {
        matrixGrid.getChildren().clear();
        matrixCells.clear();

        // 双重循环生成矩阵
        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
                TextField cell = new TextField("0");

                // 样式设置：宽度适中，居中对齐，深色背景
                cell.setPrefWidth(60);
                cell.setPrefHeight(30);
                cell.setStyle("-fx-background-color: #45475a; -fx-text-fill: white; -fx-alignment: center; -fx-background-radius: 4;");

                // 添加到 GridPane (Node, columnIndex, rowIndex)
                // 注意 GridPane.add 的参数顺序是 (列, 行)
                matrixGrid.add(cell, c, r);

                // 添加到列表以便发送时按顺序读取
                matrixCells.add(cell);
            }
        }
    }

    @FXML
    private void onSendMatrixData() {
        if (matrixCells.isEmpty()) return;

        // 在后台线程发送数据，避免卡顿 UI
        new Thread(() -> {
            try {
                int count = 0;
                for (TextField cell : matrixCells) {
                    String val = cell.getText();

                    // 发送逻辑：发送数值 + 换行符（具体协议视FPGA要求而定）
                    SerialService.getInstance().send(val + "\n");

                    // 发送延迟，防止串口缓冲区溢出
                    Thread.sleep(15);
                    count++;

                    // 更新 UI 进度 (每发送5个更新一次，减少UI线程压力)
                    if (count % 5 == 0 || count == matrixCells.size()) {
                        final int progress = count;
                        Platform.runLater(() ->
                                statusLabel.setText("Sending... " + progress + " / " + matrixCells.size())
                        );
                    }
                }

                Platform.runLater(() -> {
                    statusLabel.setText("Complete! Sent " + matrixCells.size() + " elements.");
                    statusLabel.setStyle("-fx-text-fill: #a6e3a1;"); // 绿色
                });

            } catch (Exception e) {
                Platform.runLater(() -> statusLabel.setText("Error sending data!"));
                e.printStackTrace();
            }
        }).start();
    }

    private boolean isValidInt(String str) {
        try {
            int val = Integer.parseInt(str);
            return val > 0; // 必须是正整数
        } catch (NumberFormatException e) {
            return false;
        }
    }
}