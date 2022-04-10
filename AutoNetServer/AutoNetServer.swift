//
//  NWServer.swift
//
//  Created by Rodolfo Aramayo on 4/1/22.
//  Copyright © 2022 OrbitusRobotics. All rights reserved.
//

import Foundation
import Network

@objc public protocol AutoNetServerDataDelegate {
    func didReceiveData(_ data:Data)
}

@available(macOS 10.15, *)
@objcMembers public class AutoNetServer: NSObject {
    public let port: NWEndpoint.Port
    public let listener: NWListener
    public var paused: Bool = true
    public var dataDelegate: AutoNetServerDataDelegate?
    
    private var connectionsByID: [Int: AutoNetServerConnection] = [:]
    
    public init(service:String, port:UInt16, dataDelegate:AutoNetServerDataDelegate?) {
        self.dataDelegate = dataDelegate
        self.port = NWEndpoint.Port(rawValue: port)!
        
        let tcp_options = NWProtocolTCP.Options()
        tcp_options.enableKeepalive = true
        tcp_options.keepaliveIdle = 2
        tcp_options.keepaliveCount = 1
        
        let parameters = NWParameters.init(tls: nil, tcp: tcp_options)
        parameters.allowLocalEndpointReuse = true
        
        let frameOptions = NWProtocolFramer.Options(definition:  AutoNetDataTransferProtocol.definition)
        parameters.defaultProtocolStack.applicationProtocols.insert(frameOptions, at: 0)
        
        listener = try! NWListener(using: parameters)
        listener.service = NWListener.Service(name:"ROBONET", type: service)
    }
    
    public func start() throws {
        print("server: Server starting...")
        paused = false
        listener.stateUpdateHandler = self.stateDidChange(to:)
        listener.newConnectionHandler = self.didAccept(nwConnection:)
        listener.start(queue: .main)
    }
    
    func didReceiveData(_ data: Data) {
        dataDelegate?.didReceiveData(data)
    }
    
    public func sendString(_ nsString: NSString) {
        if let data = nsString.data(using: String.Encoding.utf8.rawValue) as NSData?{
            sendMessage(data)
        }
    }
    
    public func sendMessage(_ nsData: NSData) {
        if self.connectionsByID.values.count > 0 {
            for connection in self.connectionsByID.values {
                //print("server: sendingDataTo: \(connection.id)")
                connection.send(data: nsData as Data)
            }
        } else {
            //print("server: no connections available to send")
        }
    }
    
    public func multiCast(_ nsData:NSData, sendingConnection:AutoNetServerConnection) {
        guard !paused else { return }
        //print("server: multiCast")
        let data = nsData as Data
        if !data.isEmpty {
            //let message = NSKeyedUnarchiver.unarchiveObject(with: data )
            dataDelegate?.didReceiveData(data)
            
            //---
            //Debug print but only if it is a string!
            //if let message = message as? String {
                //print("server: multiCast \(String(describing: NSKeyedUnarchiver.unarchiveObject(with: data)))")
            //}
            //---
            
            if self.connectionsByID.values.count > 0 {
                for connection in self.connectionsByID.values {
                    if connection !== sendingConnection {
                        //print("server: multiCast recipient \(connection.id)")
                        connection.send(data: data)
                    }
                }
            } else {
                //print("server: no connections available to send")
            }
        
        }
            
    }
    
    public func stateDidChange(to newState: NWListener.State) {
        switch newState {
        case .ready:
            print("server: Server ready.")
        case .failed(let error):
            print("server: Server failure, error \(error.localizedDescription)")
        default:
            break
        }
    }
    
    public func didAccept(nwConnection: NWConnection) {
        let connection = AutoNetServerConnection(nwConnection: nwConnection, delegate: self)
        self.connectionsByID[connection.id] = connection
        connection.didStopCallback = { _ in
            self.connectionDidStop(connection)
        }
        connection.start()
        //connection.send(data: "server: Welcome you are connection: \(connection.id)".data(using: .utf8)!)
        print("server: server did open connection \(connection.id)")
    }
    
    func connectionDidStop(_ connection: AutoNetServerConnection) {
        self.connectionsByID.removeValue(forKey: connection.id)
        print("server: server did close connection \(connection.id)")
    }
    
    public func connectionList() -> String {
        return connectionsByID.description
    }
    
    public func pause() {
        self.paused = true
    }
    
    public func resume() {
        self.paused = false
    }
    
    public func stop() {
        print("server: Stopping Server.")
        self.paused = true
        self.listener.stateUpdateHandler = nil
        self.listener.newConnectionHandler = nil
        self.listener.cancel()
        for connection in self.connectionsByID.values {
            connection.didStopCallback = nil
            connection.stop()
        }
        self.connectionsByID.removeAll()
    }
}
