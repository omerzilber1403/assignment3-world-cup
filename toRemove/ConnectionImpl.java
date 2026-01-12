package bgu.spl.net.impl.stomp;

import java.sql.Connection;
import java.util.concurrent.ConcurrentHashMap;

import bgu.spl.net.srv.ConnectionHandler;
import bgu.spl.net.srv.Connections;

public class ConnectionImpl<T> implements Connections<T> {
    private final ConcurrentHashMap<Integer, ConnectionHandler<T>> connectionsMap;


    public ConnectionImpl(){
        connectionsMap = new ConcurrentHashMap<>();
    }

    public void connect(int connectionId, ConnectionHandler<T> handler) {
        connectionsMap.put(connectionId, handler);
    }

    @Override
    public boolean send(int connectionId, T msg) {
       ConnectionHandler<T> handler = connectionsMap.get(connectionId);
       if(handler != null){
            handler.send(msg);
            return true;
       } else {
        return false;
       }
    }

    @Override
    public void send(String channel, T msg) {
       //TODO: implement after protocol implementation
    }

    @Override
    public void disconnect(int connectionId) {
        connectionsMap.remove(connectionId);
    }


}
