import Foundation

/// Discord's local RPC framing: a little-endian opcode and payload length,
/// four bytes each, followed by a JSON payload.
enum DiscordIPCFrame {
    enum Opcode: Int32 {
        case handshake = 0
        case frame = 1
        case close = 2
        case ping = 3
        case pong = 4
    }

    static let headerLength = 8
    /// Larger payloads than this are treated as a broken stream.
    static let maximumPayloadLength = 1 << 20

    static func encode(_ opcode: Opcode, payload: Data) -> Data {
        var data = Data(capacity: headerLength + payload.count)
        appendLittleEndian(opcode.rawValue, to: &data)
        appendLittleEndian(Int32(payload.count), to: &data)
        data.append(payload)
        return data
    }

    /// Returns the raw opcode and payload length, or nil for a malformed header.
    static func decodeHeader(_ header: Data) -> (opcode: Int32, length: Int)? {
        guard header.count == headerLength else { return nil }
        let bytes = [UInt8](header)
        let opcode = littleEndianInt32(bytes[0..<4])
        let length = Int(littleEndianInt32(bytes[4..<8]))
        guard length >= 0, length <= maximumPayloadLength else { return nil }
        return (opcode, length)
    }

    private static func appendLittleEndian(_ value: Int32, to data: inout Data) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }

    private static func littleEndianInt32(_ bytes: ArraySlice<UInt8>) -> Int32 {
        var value: UInt32 = 0
        for (shift, byte) in bytes.enumerated() {
            value |= UInt32(byte) << (8 * UInt32(shift))
        }
        return Int32(bitPattern: value)
    }
}

enum DiscordIPCMessages {
    static func handshake(clientID: String) -> Data {
        json(["v": 1, "client_id": clientID])
    }

    /// A nil activity clears whatever this app was showing.
    static func setActivity(_ activity: PresenceActivity?, processID: Int32, nonce: String) -> Data {
        var arguments: [String: Any] = ["pid": Int(processID)]
        if let activity {
            arguments["activity"] = [
                "details": activity.details,
                "state": activity.state,
                // Unix seconds, as in Discord's RPC documentation.
                "timestamps": ["start": Int(activity.startedAt.timeIntervalSince1970)],
            ] as [String: Any]
        }
        return json(["cmd": "SET_ACTIVITY", "args": arguments, "nonce": nonce])
    }

    /// Whether a reply payload reports that Discord refused the command.
    static func isError(_ payload: Data) -> Bool {
        let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any]
        return object?["evt"] as? String == "ERROR"
    }

    private static func json(_ object: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
    }
}
