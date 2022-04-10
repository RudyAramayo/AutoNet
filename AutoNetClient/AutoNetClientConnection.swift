//
//  NWClientConnection.swift
//
//  Created by Rodolfo Aramayo on 4/2/22.
//  Copyright © 2020 Apple, Inc. All rights reserved.
//

import Foundation
import Network

protocol AutoNetClientConnectionDelegate {
    func didReceiveData(_ data:Data)
}

@available(macOS 10.15, iOS 13.0, *)
class AutoNetClientConnection {
    let nwConnection: NWConnection
    let queue = DispatchQueue(label: "Client connection Q")
    var delegate: AutoNetClientConnectionDelegate? = nil
    
    init(nwConnection: NWConnection) {
        self.nwConnection = nwConnection
    }
    
    var didStopCallback: ((Error?) -> Void)? = nil
    
    public func start() {
        print("client: connection will start")
        nwConnection.stateUpdateHandler = stateDidChange(to:)
        receiveNextMessage()
        nwConnection.start(queue: queue)
    }
    
    private func stateDidChange(to state: NWConnection.State) {
        switch state {
        case .waiting(let error):
            print("client: waiting - \(error)")
            connectionDidFail(error: error)
        case .ready:
            print("client: connection ready")
        case .failed(let error):
            print("client: connectionDidFail - \(error)")
            connectionDidFail(error: error)
        default:
            break
        }
    }
    
    private func receiveNextMessage() {
        nwConnection.receiveMessage { (data, context, isComplete, error) in
            if let message = context?.protocolMetadata(definition: AutoNetDataTransferProtocol.definition) as? NWProtocolFramer.Message {
                switch message.messageType {
                case .invalid:
                    print("Received Invalid Message")
                case .sendData:
                    if let data = data, !data.isEmpty {
                        //let message = String(data: data, encoding: .utf8)
                        let message = NSKeyedUnarchiver.unarchiveObject(with: data)
                        self.delegate?.didReceiveData(data)
                        //print("client: connection did receive data: \(data as NSData) string \(message ?? "-")")
                    }
                case .setAutomationScript:
                    print("ToBeImplemented")
                }
            }
            if error == nil {
                self.receiveNextMessage()
            }
        }
    }
    
    func send(data: Data) {
        let message = NWProtocolFramer.Message(messageType: .sendData)
        let context = NWConnection.ContentContext(identifier: "SendData", metadata: [message])
        
        nwConnection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed({ error in
            if let error = error {
                self.connectionDidFail(error: error)
                return
            }
            //print("client: connection did send data \(data as NSData)")
        }))
    }
    
    func stop() {
        print("client: connection will stop")
        stop(error: nil)
    }
    
    private func connectionDidFail(error: Error) {
        print("client: connection did fail error: \(error)")
        self.stop(error: error)
    }
    
    private func connectionDidEnd() {
        print("client: connection did end")
        self.stop(error: nil)
    }
    
    private func stop(error: Error?) {
        self.nwConnection.stateUpdateHandler = nil
        self.nwConnection.cancel()
        if let didStopCallback = self.didStopCallback {
            self.didStopCallback = nil
            didStopCallback(error)
        }
    }
}

