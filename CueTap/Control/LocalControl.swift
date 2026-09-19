import Foundation

/// A named Mach message port in the user's local bootstrap session, no TCP listener.
final class LocalControl {
    private var port: CFMessagePort?
    private var source: CFRunLoopSource?
    private let handle: (ControlRequest) -> ControlResponse

    init(name: String, handle: @escaping (ControlRequest) -> ControlResponse) throws {
        self.handle = handle
        var context = CFMessagePortContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        var freeInfo = DarwinBoolean(false)
        let callback: CFMessagePortCallBack = { _, _, data, info in
            guard let info else { return nil }
            let server = Unmanaged<LocalControl>.fromOpaque(info).takeUnretainedValue()
            let response: ControlResponse
            do {
                guard let data, CFDataGetLength(data) <= 65536 else { throw ControlError("invalid_request", "Request is empty or too large.") }
                let request = try JSONDecoder().decode(ControlRequest.self, from: data as Data)
                guard request.protocolVersion == 1 else { throw ControlError("protocol_mismatch", "CLI and resident protocol versions differ. Restart with the current executable.") }
                response = server.handle(request)
            } catch { response = .failure(error) }
            guard let encoded = try? JSONEncoder().encode(response) else { return nil }
            return Unmanaged.passRetained(encoded as CFData)
        }
        guard let port = CFMessagePortCreateLocal(nil, name as CFString, callback, &context, &freeInfo), !freeInfo.boolValue else {
            throw ControlError("already_running", "CueTap is already running. Use status, load or quit.")
        }
        self.port = port
        guard let source = CFMessagePortCreateRunLoopSource(nil, port, 0) else {
            CFMessagePortInvalidate(port)
            throw ControlError("ipc_failed", "Cannot create the local control event source.")
        }
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    static func send(_ request: ControlRequest, name: String) throws -> ControlResponse {
        guard let port = CFMessagePortCreateRemote(nil, name as CFString) else {
            throw ControlError("not_running", "CueTap is not running. Run cuetap start first.")
        }
        let data = try JSONEncoder().encode(request)
        guard data.count <= 65536 else { throw ControlError("invalid_request", "Request is too large.") }
        var reply: Unmanaged<CFData>?
        let code = CFMessagePortSendRequest(port, 1, data as CFData, 2, 3, CFRunLoopMode.defaultMode.rawValue, &reply)
        guard code == kCFMessagePortSuccess, let reply else {
            throw ControlError("ipc_timeout", "Control request was not acknowledged (\(code)). Check status before retrying.")
        }
        let response = try JSONDecoder().decode(ControlResponse.self, from: reply.takeRetainedValue() as Data)
        guard response.protocolVersion == 1 else { throw ControlError("protocol_mismatch", "CLI and resident protocol versions differ.") }
        return response
    }

    deinit {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let port { CFMessagePortInvalidate(port) }
    }
}
