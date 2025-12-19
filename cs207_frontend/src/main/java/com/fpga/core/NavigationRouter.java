package com.fpga.core;

import com.fpga.model.FpgaMode;
import com.fpga.ui.MainLayoutController;

public class NavigationRouter {
    private final MainLayoutController mainController;
    private final StringBuilder buffer = new StringBuilder();

    public NavigationRouter(MainLayoutController controller) {
        this.mainController = controller;
    }

    public void processIncomingData(String chunk) {
        buffer.append(chunk);
        String currentStream = buffer.toString();

        if (currentStream.contains("Entered SHOW")) {
            switchMode(FpgaMode.SHOW);
        } else if (currentStream.contains("Entered CALC")) {
            switchMode(FpgaMode.CALC);
        } else if (currentStream.contains("Entered DEFAULT")) {
            switchMode(FpgaMode.DEFAULT);
        } else if (currentStream.contains("Entered RESTORE")) {
            // 新增跳转逻辑
            switchMode(FpgaMode.RESTORE);
        } else if (currentStream.contains("Entered RANDOM")) {
            // 新增跳转逻辑
            switchMode(FpgaMode.RANDOM);
        }

        mainController.passDataToCurrentView(chunk);
    }

    private void switchMode(FpgaMode mode) {
        System.out.println("Switching to: " + mode);
        mainController.navigate(mode);
        buffer.setLength(0);
    }
}