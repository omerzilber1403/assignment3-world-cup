import java.io.*;
import java.net.Socket;

public class SimpleStompTest {
    public static void main(String[] args) {
        try (Socket socket = new Socket("localhost", 7777);
             OutputStream out = socket.getOutputStream();
             InputStream in = socket.getInputStream()) {

            System.out.println("=== Testing STOMP Server ===\n");

            // 1. Test CONNECT
            System.out.println("[TEST 1] CONNECT");
            sendFrame(out, "CONNECT\naccept-version:1.2\nhost:localhost\nlogin:ofek\npasscode:123\n\n");
            String response1 = readFrame(in);
            System.out.println("Expected: CONNECTED frame");
            System.out.println("Got: " + response1.substring(0, Math.min(50, response1.length())));
            System.out.println(response1.startsWith("CONNECTED") ? "PASS\n" : "FAIL\n");

            // 2. Test SUBSCRIBE with Receipt
            System.out.println("[TEST 2] SUBSCRIBE");
            sendFrame(out, "SUBSCRIBE\ndestination:test-channel\nid:sub0\nreceipt:77\n\n");
            String response2 = readFrame(in);
            System.out.println("Expected: RECEIPT with receipt-id:77");
            System.out.println("Got: " + response2.substring(0, Math.min(50, response2.length())));
            System.out.println(response2.contains("receipt-id:77") ? "PASS\n" : "FAIL\n");

            // 3. Test SEND (self-broadcasting)
            System.out.println("[TEST 3] SEND");
            sendFrame(out, "SEND\ndestination:test-channel\n\nHello World!\n");
            String response3 = readFrame(in);
            System.out.println("Expected: MESSAGE frame with body");
            System.out.println("Got: " + response3.substring(0, Math.min(80, response3.length())));
            System.out.println(response3.startsWith("MESSAGE") && response3.contains("Hello World") ? "PASS\n" : "FAIL\n");

            // 4. Test UNSUBSCRIBE
            System.out.println("[TEST 4] UNSUBSCRIBE");
            sendFrame(out, "UNSUBSCRIBE\nid:sub0\nreceipt:88\n\n");
            String response4 = readFrame(in);
            System.out.println("Expected: RECEIPT with receipt-id:88");
            System.out.println("Got: " + response4.substring(0, Math.min(50, response4.length())));
            System.out.println(response4.contains("receipt-id:88") ? "PASS\n" : "FAIL\n");

            // 5. Test DISCONNECT
            System.out.println("[TEST 5] DISCONNECT");
            sendFrame(out, "DISCONNECT\nreceipt:99\n\n");
            String response5 = readFrame(in);
            System.out.println("Expected: RECEIPT with receipt-id:99");
            System.out.println("Got: " + response5.substring(0, Math.min(50, response5.length())));
            System.out.println(response5.contains("receipt-id:99") ? "PASS\n" : "FAIL\n");

            System.out.println("\n=== Checking if server closed connection ===");
            if (in.read() == -1) {
                System.out.println("PASS: Server closed the socket as expected\n");
            } else {
                System.out.println("FAIL: Server did not close socket\n");
            }

            System.out.println("=== All Eilon STOMP tests completed ===");

        } catch (Exception e) {
            System.out.println("ERROR: " + e.getMessage());
            e.printStackTrace();
        }
    }

    private static void sendFrame(OutputStream out, String frame) throws IOException {
        out.write((frame + "\0").getBytes());
        out.flush();
    }

    private static String readFrame(InputStream in) throws IOException {
        StringBuilder sb = new StringBuilder();
        int ch;
        while ((ch = in.read()) != 0 && ch != -1) {
            sb.append((char) ch);
        }
        return sb.toString();
    }
}
