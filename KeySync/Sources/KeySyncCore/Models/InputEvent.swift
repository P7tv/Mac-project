import Foundation

public enum InputEventType: String, Codable, Sendable {
    case mouseMove
    case mouseDown
    case mouseUp
    case mouseScroll
    case keyDown
    case keyUp
    case ping
    case pong
}

public struct InputEvent: Codable, Sendable, Equatable {
    public let type: InputEventType
    public let dx: Double?
    public let dy: Double?
    public let button: Int?
    public let keyCode: UInt16?
    public let modifiers: UInt32?
    public let timestamp: Double

    public init(
        type: InputEventType,
        dx: Double? = nil,
        dy: Double? = nil,
        button: Int? = nil,
        keyCode: UInt16? = nil,
        modifiers: UInt32? = nil,
        timestamp: Double = Date().timeIntervalSince1970
    ) {
        self.type = type
        self.dx = dx
        self.dy = dy
        self.button = button
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.timestamp = timestamp
    }

    // Factory methods
    public static func move(dx: Double, dy: Double) -> InputEvent {
        InputEvent(type: .mouseMove, dx: dx, dy: dy)
    }

    public static func click(button: Int, isDown: Bool) -> InputEvent {
        InputEvent(type: isDown ? .mouseDown : .mouseUp, button: button)
    }

    public static func scroll(dx: Double, dy: Double) -> InputEvent {
        InputEvent(type: .mouseScroll, dx: dx, dy: dy)
    }

    public static func key(keyCode: UInt16, modifiers: UInt32, isDown: Bool) -> InputEvent {
        InputEvent(type: isDown ? .keyDown : .keyUp, keyCode: keyCode, modifiers: modifiers)
    }
}
