package com.fpga.model;

public enum FpgaMode {
    DEFAULT("Dashboard", "view_dashboard.fxml"),
    RESTORE("Restore Matrix", "view_restore.fxml"),
    RANDOM("Random Gen", "view_random.fxml"),
    SHOW("Matrix Show", "view_show.fxml"),

    // 修改这里：指向新建的 view_calc.fxml
    CALC("Calculation", "view_calc.fxml"),

    SETUP("Setup", "view_placeholder.fxml");

    private final String displayName;
    private final String fxmlPath;

    FpgaMode(String displayName, String fxmlPath) {
        this.displayName = displayName;
        this.fxmlPath = fxmlPath;
    }

    public String getFxmlPath() { return fxmlPath; }
    public String getDisplayName() { return displayName; }
}