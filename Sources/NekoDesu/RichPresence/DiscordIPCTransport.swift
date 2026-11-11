import Foundation

enum RichPresenceDelivery: Equatable {
    case delivered
    /// Discord is not running or its local socket could not be reached.
    case discordUnavailable
    /// Discord answered but refused, e.g. an unknown application ID.
    case rejected
}

protocol RichPresenceTransport: AnyObject {
    /// Shows `activity`, or clears the presence when it is nil.
    func update(_ activity: PresenceActivity?, completion: @escaping @MainActor (RichPresenceDelivery) -> Void)
    /// Closes the connection, which also clears the presence.
    func shutdown()
}

/// Talks to the Discord app on this Mac over its local Unix socket. NekoDesu
/// itself opens no network connection; Discord relays the status.
final class DiscordIPCTransport: RichPresenceTransport {
    private let clientID: String
    private let queue = DispatchQueue(label: "NekoDesu.DiscordIPC")
    // Only touched on `queue`.
    private var socket: UnixSocket?

    init(clientID: String) {
        self.clientID = clientID
    }

    func update(_ activity: PresenceActivity?, completion: @escaping @MainActor (RichPresenceDelivery) -> Void) {
        queue.async { [self] in
            let delivery = send(activity)
            DispatchQueue.main.async {
                MainActor.assumeIsolated { completion(delivery) }
            }
        }
    }

    func shutdown() {
        queue.sync {
            socket?.close()
            socket = nil
        }
    }

    private func send(_ activity: PresenceActivity?) -> RichPresenceDelivery {
        // Nothing was shown through a connection that does not exist.
        if activity == nil && socket == nil { return .delivered }

        // A stale connection (Discord restarted) fails on first use; retry
        // once on a fresh one.
        for _ in 0..<2 {
            if socket == nil {
                let (connected, delivery) = connect()
                guard let connected else { return delivery }
                socket = connected
            }
            if let delivery = command(activity) { return delivery }
            socket?.close()
            socket = nil
        }
        return .discordUnavailable
    }

    private func connect() -> (UnixSocket?, RichPresenceDelivery) {
        for path in Self.socketPaths() {
            guard let candidate = UnixSocket(path: path) else { continue }
            let handshake = DiscordIPCFrame.encode(.handshake, payload: DiscordIPCMessages.handshake(clientID: clientID))
            guard candidate.write(handshake), let reply = readReply(from: candidate) else {
                candidate.close()
                continue
            }
            if reply.opcode == DiscordIPCFrame.Opcode.frame.rawValue, !DiscordIPCMessages.isError(reply.payload) {
                return (candidate, .delivered)
            }
            candidate.close()
            return (nil, .rejected)
        }
        return (nil, .discordUnavailable)
    }

    /// Returns nil when the connection itself failed and should be retried.
    private func command(_ activity: PresenceActivity?) -> RichPresenceDelivery? {
        guard let socket else { return nil }
        let payload = DiscordIPCMessages.setActivity(
            activity,
            processID: ProcessInfo.processInfo.processIdentifier,
            nonce: UUID().uuidString
        )
        guard socket.write(DiscordIPCFrame.encode(.frame, payload: payload)),
              let reply = readReply(from: socket) else { return nil }
        guard reply.opcode == DiscordIPCFrame.Opcode.frame.rawValue else { return nil }
        return DiscordIPCMessages.isError(reply.payload) ? .rejected : .delivered
    }

    /// Reads the next frame, answering any pings that arrive first. Replies
    /// are always read so Discord's side of the socket never backs up.
    private func readReply(from socket: UnixSocket) -> (opcode: Int32, payload: Data)? {
        for _ in 0..<4 {
            guard let header = socket.read(count: DiscordIPCFrame.headerLength),
                  let (opcode, length) = DiscordIPCFrame.decodeHeader(header),
                  let payload = socket.read(count: length) else { return nil }
            guard opcode == DiscordIPCFrame.Opcode.ping.rawValue else { return (opcode, payload) }
            guard socket.write(DiscordIPCFrame.encode(.pong, payload: payload)) else { return nil }
        }
        return nil
    }

    /// Discord listens on `discord-ipc-0` through `-9` in the temporary directory.
    static func socketPaths(temporaryDirectory: String = NSTemporaryDirectory()) -> [String] {
        (0..<10).map { (temporaryDirectory as NSString).appendingPathComponent("discord-ipc-\($0)") }
    }
}

/// A connected Unix domain stream socket with short timeouts.
final class UnixSocket {
    private var descriptor: Int32

    init?(path: String, timeoutSeconds: Int = 2) {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(path.utf8)
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        guard pathBytes.count < capacity else { return nil }
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            buffer.copyBytes(from: pathBytes)
        }

        let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return nil }

        var enabled: Int32 = 1
        // A closed peer must produce an error, not kill the app with SIGPIPE.
        setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &enabled, socklen_t(MemoryLayout<Int32>.size))
        var timeout = timeval(tv_sec: timeoutSeconds, tv_usec: 0)
        setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(descriptor, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else {
            Darwin.close(descriptor)
            return nil
        }
        self.descriptor = descriptor
    }

    deinit { close() }

    func write(_ data: Data) -> Bool {
        guard descriptor >= 0 else { return false }
        return data.withUnsafeBytes { buffer -> Bool in
            var offset = 0
            while offset < buffer.count {
                let written = Darwin.write(descriptor, buffer.baseAddress?.advanced(by: offset), buffer.count - offset)
                guard written > 0 else { return false }
                offset += written
            }
            return true
        }
    }

    /// Reads exactly `count` bytes, or nil on timeout, error, or end of stream.
    func read(count: Int) -> Data? {
        guard descriptor >= 0, count >= 0 else { return nil }
        var data = Data(count: count)
        var offset = 0
        while offset < count {
            let received = data.withUnsafeMutableBytes { buffer in
                Darwin.read(descriptor, buffer.baseAddress?.advanced(by: offset), count - offset)
            }
            guard received > 0 else { return nil }
            offset += received
        }
        return data
    }

    func close() {
        guard descriptor >= 0 else { return }
        Darwin.close(descriptor)
        descriptor = -1
    }
}
