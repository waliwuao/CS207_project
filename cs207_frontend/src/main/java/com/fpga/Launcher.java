package com.fpga;

public class Launcher {
    public static void main(String[] args) {
        // 代理调用 App 的 main 方法，绕过 JavaFX 模块检查
        App.main(args);
    }
}