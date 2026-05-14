import Foundation
import SwiftUI

final class GamepadState: ObservableObject {
    @Published var leftX: UInt8 = 128
    @Published var leftY: UInt8 = 128
    @Published var rightX: UInt8 = 128
    @Published var rightY: UInt8 = 128
    @Published var hat: UInt8 = 8
    @Published var buttons: UInt16 = 0

    enum Button: UInt16 {
        case square = 1 << 0
        case cross = 1 << 1
        case circle = 1 << 2
        case triangle = 1 << 3
        case l1 = 1 << 4
        case r1 = 1 << 5
        case l2 = 1 << 6
        case r2 = 1 << 7
        case share = 1 << 8
        case options = 1 << 9
    }

    var report: Data {
        var bytes: [UInt8] = []
        bytes.append(0x01) // Report ID
        bytes.append(leftX)
        bytes.append(leftY)
        bytes.append(rightX)
        bytes.append(rightY)
        bytes.append(hat)
        bytes.append(UInt8(buttons & 0x00ff))
        bytes.append(UInt8((buttons >> 8) & 0x00ff))
        return Data(bytes)
    }

    func set(_ button: Button, pressed: Bool) {
        if pressed {
            buttons |= button.rawValue
        } else {
            buttons &= ~button.rawValue
        }
    }

    func resetLeftStick() {
        leftX = 128
        leftY = 128
        hat = 8
    }

    func setDirection(from vector: CGVector) {
        let length = sqrt(vector.dx * vector.dx + vector.dy * vector.dy)
        guard length > 18 else {
            resetLeftStick()
            return
        }

        let clampedX = max(-1, min(1, vector.dx / 90))
        let clampedY = max(-1, min(1, vector.dy / 90))
        leftX = UInt8(max(0, min(255, Int(128 + clampedX * 127))))
        leftY = UInt8(max(0, min(255, Int(128 + clampedY * 127))))

        let angle = atan2(vector.dy, vector.dx) * 180 / .pi
        switch angle {
        case -112.5 ..< -67.5:
            hat = 0 // up
        case -67.5 ..< -22.5:
            hat = 1 // up-right
        case -22.5 ..< 22.5:
            hat = 2 // right
        case 22.5 ..< 67.5:
            hat = 3 // down-right
        case 67.5 ..< 112.5:
            hat = 4 // down
        case 112.5 ..< 157.5:
            hat = 5 // down-left
        case -157.5 ..< -112.5:
            hat = 7 // up-left
        default:
            hat = 6 // left
        }
    }
}
