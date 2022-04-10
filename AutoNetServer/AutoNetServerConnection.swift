//
//  NWServerConnection.swift
//
//  Created by Rodolfo Aramayo on 4/2/22.
//  Copyright © 2020 Apple, Inc. All rights reserved.
//

import Foundation
import Network

@available(macOS 10.15, *)
public class AutoNetServerConnection {
    let MTU = 65536
    
    private static var nextID: Int = 0
    let serverDelegate: AutoNetServer
    let connection: NWConnection
    let id: Int
    
    init(nwConnection: NWConnection, delegate:AutoNetServer ) {
        connection = nwConnection
        serverDelegate = delegate
        id = AutoNetServerConnection.nextID
        AutoNetServerConnection.nextID += 1
    }
    
    var didStopCallback: ((Error?) -> Void)? = nil
    
    func start() {
        //print("server: connection \(id) will start")
        connection.stateUpdateHandler = self.stateDidChange(to:)
        receiveNextMessage()
        connection.start(queue: .main)
    }
    
    private func stateDidChange(to state: NWConnection.State) {
        switch state {
        case .waiting(let error):
            connectionDidFail(error: error)
        case .ready:
            print("server: connection \(id) ready")
        case .failed(let error):
            connectionDidFail(error: error)
        default:
            break;
        }
    }
    
    private func receiveNextMessage() {
        connection.receiveMessage { (data, context, isComplete, error) in
            if let message = context?.protocolMetadata(definition: AutoNetDataTransferProtocol.definition) as? NWProtocolFramer.Message {
                switch message.messageType {
                case .invalid:
                    print("server: Received Invalid Message")
                case .sendData: //These messages are multi-cast to the whole group of connections
                    if let data = data, !data.isEmpty {
                        //let message = String(data: data, encoding: .utf8)
                        //print("server: connection \(self.id) did receive, data: \(data as NSData) string: \(message ?? "-")")
                        
                        self.serverDelegate.multiCast(data as NSData, sendingConnection: self)
                    }
                case .setAutomationScript:
                    print("server: ToBeImplemented")
                }
                if error == nil {
                    self.receiveNextMessage()
                }
            }
        }
    }
    
    func send(data: Data) {
        let message = NWProtocolFramer.Message(messageType: .sendData)
        let context  = NWConnection.ContentContext(identifier: "SendData",
                                                   metadata: [message])
        
        self.connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed({ error in
            if let error = error {
                self.connectionDidFail(error: error)
                return
            }
            //print("server: connection \(self.id) did send data: \(data as NSData)")
        }))
    }
    
    func stop() {
        //print("server: connection \(id) will stop")
    }
    
    private func connectionDidFail(error: Error) {
        //print("server: connection \(id) did end")
        stop(error: nil)
    }
    
    private func connectionDidEnd() {
        //print("server: connection \(id) did end")
        stop(error: nil)
    }
    
    private func stop(error: Error?) {
        connection.stateUpdateHandler = nil
        connection.cancel()
        if let didStopCallback = didStopCallback {
            self.didStopCallback = nil
            didStopCallback(error)
        }
    }
}
