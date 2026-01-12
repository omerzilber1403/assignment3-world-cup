package bgu.spl.net.impl.stomp;

import java.util.Arrays;

import bgu.spl.net.api.MessageEncoderDecoder;

public class StompEncDec implements MessageEncoderDecoder<String> {
    private byte[] bytes = new byte[1024];
    private int len = 0;

    @Override
    public String decodeNextByte(byte nextByte) {
        if(nextByte == '\u0000'){
            String res = new String(bytes, 0, len);
            len = 0;
            return res;

        } else {
            if (len >= bytes.length) {
            bytes = Arrays.copyOf(bytes, len * 2);
        }
            bytes[len++] = nextByte;
            return null;
        }
        
    }

    @Override
    public byte[] encode(String message) {
        return (message + "\u0000").getBytes();
       
    }

    

}
