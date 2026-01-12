package bgu.spl.net.impl.stomp;

import bgu.spl.net.api.MessageEncoderDecoder;
import java.util.HashMap;
import java.util.Map;

public class StompEncoderDecoder implements MessageEncoderDecoder<Frame> {
    
    // State machine for parsing STOMP frames
    private enum State {
        COMMAND, HEADERS, BODY
    }
    
    private State currentState;
    private StringBuilder lineBuffer;
    private String command;
    private Map<String, String> headers;
    private StringBuilder bodyBuffer;
    
    public StompEncoderDecoder() {
        reset();
    }
    
    private void reset() {
        currentState = State.COMMAND;
        lineBuffer = new StringBuilder();
        command = null;
        headers = new HashMap<>();
        bodyBuffer = new StringBuilder();
    }
    
    @Override
    public Frame decodeNextByte(byte nextByte) {
        // Check for null terminator - frame is complete
        if (nextByte == 0) {
            return completeFrame();
        }
        
        char c = (char) nextByte;
        
        switch (currentState) {
            case COMMAND:
                return processCommandByte(c);
            case HEADERS:
                return processHeadersByte(c);
            case BODY:
                return processBodyByte(c);
            default:
                return null;
        }
    }
    
    private Frame processCommandByte(char c) {
        if (c == '\n') {
            // End of command line, move to headers
            command = lineBuffer.toString().trim();
            lineBuffer = new StringBuilder();
            currentState = State.HEADERS;
        } else if (c != '\r') {
            lineBuffer.append(c);
        }
        return null;
    }
    
    private Frame processHeadersByte(char c) {
        if (c == '\n') {
            String line = lineBuffer.toString();
            lineBuffer = new StringBuilder();
            
            if (line.isEmpty() || line.equals("\r")) {
                // Empty line means headers done, now read body
                currentState = State.BODY;
            } else {
                // Parse header: key:value
                int colonIndex = line.indexOf(':');
                if (colonIndex > 0) {
                    String key = line.substring(0, colonIndex).trim();
                    String value = line.substring(colonIndex + 1).trim();
                    headers.put(key, value);
                }
            }
        } else if (c != '\r') {
            lineBuffer.append(c);
        }
        return null;
    }
    
    private Frame processBodyByte(char c) {
        bodyBuffer.append(c);
        return null;
    }
    
    private Frame completeFrame() {
        Frame frame = new Frame(
            command != null ? command : "",
            new HashMap<>(headers),
            bodyBuffer.toString()
        );
        reset(); // prepare for next frame
        return frame;
    }
    
    @Override
    public byte[] encode(Frame message) {
        if (message == null) {
            return new byte[0];
        }
        return message.toString().getBytes();
    }
}
