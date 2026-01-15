package bgu.spl.net.impl.stomp;

import bgu.spl.net.srv.Server;

public class StompServer {

    public static void main(String[] args) {
        //TODO
        if (args.length < 2) {
            System.err.println("Usage: StompServer <port> <server-type>");
            System.err.println("server-type: tpc | reactor");
            return;
        }
        
        int port = Integer.parseInt(args[0]);
        String serverType = args[1];
        
        Server<String> server;
        
        if ("tpc".equals(serverType)) {
            server = Server.threadPerClient(
                port,
                StompMessagingProtocolImpl::new,
                StompEncoderDecoder::new
            );
        } else if ("reactor".equals(serverType)) {
            server = Server.reactor(
                Runtime.getRuntime().availableProcessors(),
                port,
                StompMessagingProtocolImpl::new,
                StompEncoderDecoder::new
            );
        } else {
            System.err.println("Unknown server type: " + serverType);
            return;
        }
        
        server.serve();
    }
}