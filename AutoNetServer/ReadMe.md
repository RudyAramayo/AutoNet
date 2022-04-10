# AutoNetServer ReadMe

This server will automagically listen for NWClients and multi-cast every message from 1 connction to all other connections

## Usage:

### Add a property to your class to store the server
```
var server: AutoNetServer?
```
### Initialize the server with a service name and port
```
public func initializeServer() {
    server = AutoNetServer(service: "_myappname._tcp")
    do {
        try server?.start()
    } catch {
        print("ERROR: \(error)")
    }
}
```
### Stop the server
```
server?.stop()
```
