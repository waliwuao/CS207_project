package com.fpga.core;

import com.fazecast.jSerialComm.SerialPort;
import com.fazecast.jSerialComm.SerialPortDataListener;
import com.fazecast.jSerialComm.SerialPortEvent;
import javafx.application.Platform;
import java.util.function.Consumer;

public class SerialService {
    private static SerialService instance;
    private SerialPort activePort;
    private Consumer<String> onDataReceived;

    private SerialService() {}

    public static SerialService getInstance() {
        if (instance == null) instance = new SerialService();
        return instance;
    }

    public void setOnDataReceived(Consumer<String> listener) {
        this.onDataReceived = listener;
    }

    public boolean connect(String portName, int baudRate) {
        activePort = SerialPort.getCommPort(portName);
        activePort.setBaudRate(baudRate);

        if (activePort.openPort()) {
            activePort.addDataListener(new SerialPortDataListener() {
                @Override
                public int getListeningEvents() { return SerialPort.LISTENING_EVENT_DATA_RECEIVED; }

                @Override
                public void serialEvent(SerialPortEvent event) {
                    byte[] newData = event.getReceivedData();
                    String text = new String(newData);
                    if (onDataReceived != null) {
                        Platform.runLater(() -> onDataReceived.accept(text));
                    }
                }
            });
            return true;
        }
        return false;
    }

    public void send(String data) {
        if (activePort != null && activePort.isOpen()) {
            byte[] bytes = data.getBytes();
            activePort.writeBytes(bytes, bytes.length);
        }
    }

    public SerialPort[] getAvailablePorts() {
        return SerialPort.getCommPorts();
    }
}