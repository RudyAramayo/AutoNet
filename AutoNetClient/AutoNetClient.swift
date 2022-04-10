//
//  AutoNetClient.swift
//
//  Created by Rodolfo Aramayo on 4/1/22.
//  Copyright © 2020 Apple, Inc. All rights reserved.
//

import Foundation
import Network

@objc public protocol AutoNetClientDataDelegate {
    func didReceiveData(_ data:NSData)
}

@available(macOS 10.15, iOS 13.0, *)
@objcMembers public class AutoNetClient: NSObject, AutoNetClientConnectionDelegate {
    var connection: AutoNetClientConnection? = nil
    public var host: NWEndpoint.Host? = nil
    public var port: NWEndpoint.Port? = nil
    public var service: String? = ""
    public var browser: NWBrowser? = nil
    public var isConnected = false
    
    public init(service:String) {
        self.service = service
        super.init()
        self.startBrowsing()
    }
    
    public init(host: String, port: UInt16) {
        
        self.host = NWEndpoint.Host(host)
        self.port = NWEndpoint.Port(rawValue: port)!

        //Start manual connection to host and port
        let tcp_options = NWProtocolTCP.Options()
        tcp_options.enableKeepalive = true
        tcp_options.keepaliveIdle = 2
        tcp_options.keepaliveCount = 1
        
        let parameters = NWParameters.init(tls: nil, tcp: tcp_options)
        parameters.allowLocalEndpointReuse = true

        let frameOptions = NWProtocolFramer.Options(definition: AutoNetDataTransferProtocol.definition)
        parameters.defaultProtocolStack.applicationProtocols.insert(frameOptions, at: 0)
        if let host = self.host, let port = self.port {
            let nwConnection = NWConnection(host: host, port: port, using: parameters)
            connection = AutoNetClientConnection(nwConnection: nwConnection)
        }
    }
    
    public func startBrowsing() {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        // Browse for a custom "_tictactoe._tcp" service type.
        guard let service = self.service else { return }
        
        let browser = NWBrowser(for: .bonjour(type: service, domain: nil), using: parameters)
        self.browser = browser
        browser.stateUpdateHandler = { newState in
            switch newState {
            case .failed(let error):
                // Restart the browser if it fails.
                print("client: Browser failed with \(error), restarting")
                browser.cancel()
                self.startBrowsing()
            default:
                break
            }
        }

        // When the list of discovered endpoints changes, refresh the delegate.
        browser.browseResultsChangedHandler = { results, changes in
            //self.dataDelegate?.refreshResults(results: results)
            print("client: browseResultsChanged \(results) - \(changes)")
            
            switch changes.first {
                case let .added(result):
                    print("client: added \(result)")
                    break;
                case let .changed(old: oldResult, new: newResult, flags: _):
                    print("client: changed Old - \(oldResult) to New - \(newResult)")
                    break;
                case let .removed(result):
                    print("client: removed \(result)")
                default:
                    break;
            }
            
            //TODO (follow): validate this because its dropping new clients when old connections are dead. Need keepalive messages to heartbeat or else we may be out of sync?
            //guard !self.isConnected else { print("client: exiting since we are still connected"); return }
            
            let result = results.first
            
            if let browseResult = result,
                case let NWEndpoint.service(name: name, type: serviceType, domain: domain, interface: interface) = browseResult.endpoint {
                
                print("client: name - \(name)\ntype -\(serviceType)\ndomain - \(domain)\ninterface - \(String(describing: interface))")
                
                let tcp_options = NWProtocolTCP.Options()
                tcp_options.enableKeepalive = true
                tcp_options.keepaliveIdle = 2
                
                let parameters = NWParameters.init(tls: nil, tcp: tcp_options)
                parameters.allowLocalEndpointReuse = true

                let frameOptions = NWProtocolFramer.Options(definition: AutoNetDataTransferProtocol.definition)
                parameters.defaultProtocolStack.applicationProtocols.insert(frameOptions, at: 0)
                
                //let nwConnection = NWConnection(host: self.host, port: self.port, using: parameters)
                let nwConnection = NWConnection(to: browseResult.endpoint, using: parameters)
                
                self.connection = AutoNetClientConnection(nwConnection: nwConnection)
                self.start()
                self.isConnected = true;
                //browser.cancel()
            }
            
        }

        // Start browsing and ask for updates on the main queue.
        browser.start(queue: .main)

    }
    
    public var dataDelegate:AutoNetClientDataDelegate?
    
    func didReceiveData(_ data: Data) {
        dataDelegate?.didReceiveData(data as NSData)
    }
    
    public func start() {
        if let host = host, let port = port {
            print("client: started \(host)) \(port))")
        } else {
            print("client: started \(String(describing: connection?.nwConnection.endpoint)) \(String(describing: port))")
        }
        
        connection?.didStopCallback = didStopCallback(error:)
        connection?.delegate = self
        connection?.start()
    }
    
    public func connectionDescription() -> String {
        return connection.debugDescription
    }
    
    public func stop () {
        isConnected = false
        connection?.stop()
    }
    
    public func send(data: Data) {
        connection?.send(data: data)
    }
    
    func didStopCallback(error: Error?) {
        isConnected = false
        if error == nil {
            print("client: DidStop Client")
        } else {
            print("client: DidStop Client ***FAILURE***")
        }
    }
    
}
