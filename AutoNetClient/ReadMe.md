AutoNetClient ReadMe

This client will automagically connect to a listener (AutoNetServer) endpoint. If the listener endpoint shuts down the client
will automagically reconnect once the listener is back up, always staying connected is the feature of this client-server connection model.


Usage:

// 1. Conform to AutoNetClientDataDelegate Protocol
@interface MyClassGoesHere() <AutoNetClientDataDelegate>

@objc protocol AutoNetClientDataDelegate {
    func didReceiveData(_ data:Data)
}
// 2. Add AutoNetClient property to your class
@property (readwrite, retain) AutoNetClient *client;
// 3. Initialize AutoNetClient and set dataDelegate
- (void) bootClientConnection {
    //_client = [[AutoNetClient alloc] initWithHost:@"" port:0];
    _client = [[AutoNetClient alloc] initWithService:@"_myappname._tcp"];
    _client.dataDelegate = self;
    [_client start];
}

// 4. Send Data like this
[_client sendWithData:data];
