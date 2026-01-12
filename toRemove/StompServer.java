package bgu.spl.net.impl.stomp;

import bgu.spl.net.srv.Server;

public class StompServer {

    public static void main(String[] args) {
        if(args.length < 2){
            System.out.println("should get exactly 2 args : <port> <tpc/reactor>");
            System.exit(1);
        }
        String port = args[0];
        String serverType = args[1];
    

        
    }
}
