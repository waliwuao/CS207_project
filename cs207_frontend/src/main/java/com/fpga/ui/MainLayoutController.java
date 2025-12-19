package com.fpga.ui;

import com.fazecast.jSerialComm.SerialPort;
import com.fpga.core.NavigationRouter;
import com.fpga.core.SerialService;
import com.fpga.model.FpgaMode;
import javafx.fxml.FXML;
import javafx.fxml.FXMLLoader;
import javafx.scene.Parent;
import javafx.scene.control.ComboBox;
import javafx.scene.control.Label;
import javafx.scene.control.TextField;
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.StackPane;
import javafx.scene.layout.VBox;

import java.io.IOException;

public class MainLayoutController {

    @FXML private BorderPane rootPane;
    @FXML private StackPane contentArea;
    @FXML private Label statusLabel;
    @FXML private ComboBox<String> portSelector;
    @FXML private Label currentModeLabel;

    // 模拟相关控件
    @FXML private VBox simulationBox; // 对应FXML中的 simulationBox
    @FXML private TextField simulationInput;

    private NavigationRouter router;
    private boolean isDefaultPort = false;

    @FXML
    public void initialize() {
        router = new NavigationRouter(this);

        // 1. 初始化串口列表，手动添加 "default" 选项
        portSelector.getItems().add("default");

        // 获取系统真实串口
        for (SerialPort port : SerialService.getInstance().getAvailablePorts()) {
            portSelector.getItems().add(port.getSystemPortName());
        }

        // 默认选中 default
        portSelector.setValue("default");

        // 初始加载 Dashboard
        navigate(FpgaMode.DEFAULT);
    }

    @FXML
    private void onConnectClicked() {
        String selectedPort = portSelector.getValue();
        if (selectedPort == null) return;

        // --- 逻辑分支：模拟模式 vs 真实模式 ---

        if (selectedPort.equals("default")) {
            // 进入模拟模式
            isDefaultPort = true;
            statusLabel.setText("Status: SIMULATION MODE");
            statusLabel.setStyle("-fx-text-fill: #f9e2af;"); // 黄色文字

            // 显示模拟输入框
            setSimulationBoxVisible(true);

            System.out.println("System entered default simulation mode.");
        } else {
            // 进入真实串口模式
            isDefaultPort = false;
            // 隐藏模拟输入框
            setSimulationBoxVisible(false);

            boolean success = SerialService.getInstance().connect(selectedPort, 115200);
            if (success) {
                statusLabel.setText("Status: CONNECTED (" + selectedPort + ")");
                statusLabel.setStyle("-fx-text-fill: #00ff9d;"); // 亮绿色

                // 绑定真实数据接收回调
                SerialService.getInstance().setOnDataReceived(router::processIncomingData);
            } else {
                statusLabel.setText("Status: CONN ERROR");
                statusLabel.setStyle("-fx-text-fill: #ff0055;"); // 红色
            }
        }
    }

    @FXML
    private void onSimulateSend() {
        // 只有在 Default 模式下才允许模拟发送
        if (!isDefaultPort) return;

        String data = simulationInput.getText();
        if (data != null && !data.isEmpty()) {
            // 直接调用 Router 处理数据，模拟从串口接收到了数据
            System.out.println("Simulating RX: " + data);
            router.processIncomingData(data);

            // 可选：发送后清空输入框
            simulationInput.clear();
        }
    }

    // 辅助方法：控制模拟框的显示与布局管理
    private void setSimulationBoxVisible(boolean visible) {
        simulationBox.setVisible(visible);
        simulationBox.setManaged(visible); //如果不managed，隐藏时不占位
    }

    public void navigate(FpgaMode mode) {
        try {
            FXMLLoader loader = new FXMLLoader(getClass().getResource("/fxml/" + mode.getFxmlPath()));
            Parent view = loader.load();
            contentArea.getChildren().clear();
            contentArea.getChildren().add(view);

            currentModeLabel.setText(mode.getDisplayName().toUpperCase());
        } catch (IOException e) {
            System.err.println("Failed to navigate to: " + mode.getFxmlPath());
            e.printStackTrace();
        }
    }

    public void passDataToCurrentView(String data) {
        // 这里可以将数据传递给当前显示的子页面 Controller
        // System.out.println("Data passed to view: " + data);
    }
}