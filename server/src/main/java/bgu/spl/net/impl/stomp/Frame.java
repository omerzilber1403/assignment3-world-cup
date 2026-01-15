package bgu.spl.net.impl.stomp;

import java.util.HashMap;
import java.util.Map;

public class Frame {
    private String command;
    private Map<String, String> headers;
    private String body;

    public Frame() {
        this.command = "";
        this.headers = new HashMap<>();
        this.body = "";
    }

    public Frame(String command, Map<String, String> headers, String body) {
        this.command = command;
        if (headers != null) {
            this.headers = new HashMap<>(headers);
        } else {
            this.headers = new HashMap<>();
        }
        if (body != null) {
            this.body = body;
        } else {
            this.body = "";
        }
    }

    // Getters and Setters
    public String getCommand() {
        return command;
    }

    public Map<String, String> getHeaders() {
        return headers;
    }

    public String getBody() {
        return body;
    }

    public void setCommand(String command) {
        this.command = command;
    }

    public void setHeaders(Map<String, String> headers) {
        this.headers = headers;
    }

    public void setBody(String body) {
        this.body = body;
    }

    public void addHeader(String key, String value) {
        this.headers.put(key, value);
    }

    public String getHeader(String key) {
        return this.headers.get(key);
    }

    // Convert Frame to STOMP format string
    @Override
    public String toString() {
        StringBuilder sb = new StringBuilder();
        sb.append(command).append("\n");
        
        for (Map.Entry<String, String> entry : headers.entrySet()) {
            sb.append(entry.getKey()).append(":").append(entry.getValue()).append("\n");
        }
        
        sb.append("\n");
        
        // Body
        sb.append(body);
        
        // Null terminator
        sb.append("\u0000");
        
        return sb.toString();
    }

    // Parse STOMP string to Frame
    public static Frame parse(String message) {
        if (message == null || message.isEmpty()) {
            return null;
        }
        
        Frame frame = new Frame();
        String cleanMessage = message.replace("\u0000", "");
        String[] lines = cleanMessage.split("\n", -1); // -1 keeps empty strings
        
        if (lines.length < 1) {
            return null;
        }
        
        frame.setCommand(lines[0].trim());
        
        // Parse headers until empty line
        int i = 1;
        while (i < lines.length && !lines[i].isEmpty()) {
            String line = lines[i];
            int colonIndex = line.indexOf(':');
            if (colonIndex > 0) {
                String key = line.substring(0, colonIndex);
                String value = line.substring(colonIndex + 1);
                frame.addHeader(key, value);
            }
            i++;
        }
        
        i++; // skip empty line separator
        
        // Rest is body
        StringBuilder bodyBuilder = new StringBuilder();
        while (i < lines.length) {
            if (bodyBuilder.length() > 0) {
                bodyBuilder.append("\n");
            }
            bodyBuilder.append(lines[i]);
            i++;
        }
        frame.setBody(bodyBuilder.toString());
        
        return frame;
    }

    // Helper methods to create common frames
    public static Frame createConnected() {
        Map<String, String> headers = new HashMap<>();
        headers.put("version", "1.2");
        return new Frame("CONNECTED", headers, "");
    }

    public static Frame createReceipt(String receiptId) {
        Map<String, String> headers = new HashMap<>();
        headers.put("receipt-id", receiptId);
        return new Frame("RECEIPT", headers, "");
    }

    public static Frame createError(String message, String receiptId, String detailedMessage) {
        Map<String, String> headers = new HashMap<>();
        headers.put("message", message);
        if (receiptId != null) {
            headers.put("receipt-id", receiptId);
        }
        return new Frame("ERROR", headers, detailedMessage != null ? detailedMessage : "");
    }

    public static Frame createMessage(int messageId, String destination, int subscriptionId, String body) {
        Map<String, String> headers = new HashMap<>();
        headers.put("message-id", String.valueOf(messageId));
        headers.put("destination", destination);
        headers.put("subscription", String.valueOf(subscriptionId));
        return new Frame("MESSAGE", headers, body);
    }
}
