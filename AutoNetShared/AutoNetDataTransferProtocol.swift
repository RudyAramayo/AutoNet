//
//  AutoNetDataTransferProtocol.swift
//  
//  Created by Rodolfo Aramayo on 3/31/22.
//  Copyright © 2020 Apple, Inc. All rights reserved.
//

import Foundation
import Network

// 1. Define the types of commands your service will use.
enum DataMessageType: UInt32 {
    case invalid = 0
    case sendData = 1
    case setAutomationScript = 2
}

// 2. Create a class that implements a framing protocol.
@available(OSX 10.15, *)
class AutoNetDataTransferProtocol: NWProtocolFramerImplementation {
    // 3. Create a global definition of your game protocol to add to connections.
    static let definition = NWProtocolFramer.Definition(implementation: AutoNetDataTransferProtocol.self)
    
    // 4. Set a name for your protocol for use in debugging.
    static var label: String { return "DataTransferProtocol" }
    
    // 5. Set the default behavior for most framing protocol functions.
    required init(framer: NWProtocolFramer.Instance) { }
    func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult { return .ready }
    func wakeup(framer: NWProtocolFramer.Instance) { }
    func stop(framer: NWProtocolFramer.Instance) -> Bool { return true }
    func cleanup(framer: NWProtocolFramer.Instance) { }
    
    // 6. Whenever the application sends a message, add your protocol header and forward the bytes.
    func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool) {
        // a. Extract the type of message.
        let type = message.messageType
        // b. Create a header using the type and length.
        let header = DataTransferProtocolHeader(type: type.rawValue, length: UInt32(messageLength))
        
        // c. Write the header.
        framer.writeOutput(data: header.encodedData)
        
        // d. Ask the connection to insert the content of the application message after your header.
        do {
            try framer.writeOutputNoCopy(length: messageLength)
        } catch let error {
            print("Error writing: \(error)")
        }
    }
    // 7. Whenever new bytes are available to read, try to parse out your message format.
    func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        while true {
            // a. Try to read out a single header.
            var tempHeader: DataTransferProtocolHeader? = nil
            let headerSize = DataTransferProtocolHeader.encodedSize
            let parsed = framer.parseInput(minimumIncompleteLength: headerSize, maximumLength: headerSize) { (buffer, isComplete) -> Int in
                guard let buffer = buffer else {
                    return 0
                }
                if buffer.count < headerSize {
                    return 0
                }
                tempHeader = DataTransferProtocolHeader(buffer)
                return headerSize
            }
            
            // b. If you can't parse out a complete header, stop parsing and ask for headerSize more bytes.
            guard parsed, let header = tempHeader else {
                return headerSize
            }
            
            // c. Create an object to deliver the message.
            var messageType = DataMessageType.invalid
            if let parsedMessageType = DataMessageType(rawValue: header.type) {
                messageType = parsedMessageType
            }
            let message = NWProtocolFramer.Message(messageType: messageType)
            
            // d. Deliver the body of the message, along with the message object.
            if !framer.deliverInputNoCopy(length: Int(header.length), message: message, isComplete: true) {
                return 0
            }
        }
    }
}


// 8. Extend framer messages to handle storing your command types in the message metadata.
@available(OSX 10.15, *)
extension NWProtocolFramer.Message {
    convenience init(messageType: DataMessageType) {
        self.init(definition: AutoNetDataTransferProtocol.definition)
        self.messageType = messageType
    }
    
    var messageType: DataMessageType {
        get {
            if let type = self["MessageType"] as? DataMessageType {
                return type
            } else {
                return .invalid
            }
        }
        set {
            self["MessageType"] = newValue
        }
    }
}

// 9. Define a protocol header struct to help encode and decode bytes.
struct DataTransferProtocolHeader: Codable {
    let type: UInt32
    let length: UInt32
    
    init(type: UInt32, length: UInt32) {
        self.type = type
        self.length = length
    }
    
    init(_ buffer: UnsafeMutableRawBufferPointer) {
        var tempType: UInt32 = 0
        var tempLength: UInt32 = 0
        withUnsafeMutableBytes(of: &tempType) { typePtr in
            typePtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: 0),
                                                            count: MemoryLayout<UInt32>.size))
        }
        withUnsafeMutableBytes(of: &tempLength) { lengthPtr in
            lengthPtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: MemoryLayout<UInt32>.size),
                                                              count: MemoryLayout<UInt32>.size))
        }
        type = tempType
        length = tempLength
    }
    
    var encodedData: Data {
        var tempType = type
        var tempLength = length
        var data = Data(bytes: &tempType, count: MemoryLayout<UInt32>.size)
        data.append(Data(bytes: &tempLength, count: MemoryLayout<UInt32>.size))
        return data
    }
    
    static var encodedSize: Int {
        return MemoryLayout<UInt32>.size * 2
    }
}
