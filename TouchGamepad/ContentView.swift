import SwiftUI

struct ContentView: View {
    @StateObject private var gamepadState = GamepadState()
    @State private var bluetoothPeripheral: BluetoothGamepadPeripheral?

    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, Color(red: 0.07, green: 0.08, blue: 0.12)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                topBar
                HStack(spacing: 16) {
                    leftController
                    centerPanel
                    rightController
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 10)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if bluetoothPeripheral == nil {
                bluetoothPeripheral = BluetoothGamepadPeripheral(state: gamepadState)
            }
        }
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Touch Gamepad")
                    .font(.headline)
                    .bold()
                Text(bluetoothPeripheral?.status ?? "Bluetooth permission needed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                bluetoothPeripheral?.requestBluetoothAndStart()
            } label: {
                Label("Enable Bluetooth", systemImage: "dot.radiowaves.left.and.right")
                    .font(.subheadline.bold())
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
    }

    private var leftController: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 2))
                    .frame(width: size * 0.82, height: size * 0.82)

                ForEach(directionLabels, id: \.label) { item in
                    Text(item.label)
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(item.primary ? 0.95 : 0.5))
                        .position(
                            x: center.x + cos(item.angle) * size * item.radius,
                            y: center.y + sin(item.angle) * size * item.radius
                        )
                }

                Circle()
                    .fill(.white.opacity(0.15))
                    .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
                    .frame(width: size * 0.28, height: size * 0.28)
                    .position(center)

                Text("LEFT STICK / WASD")
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.6))
                    .position(x: center.x, y: proxy.size.height - 12)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let vector = CGVector(dx: value.location.x - center.x, dy: value.location.y - center.y)
                        gamepadState.setDirection(from: vector)
                    }
                    .onEnded { _ in
                        gamepadState.resetLeftStick()
                    }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var centerPanel: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                HoldButton(title: "SHARE") { pressed in gamepadState.set(.share, pressed: pressed) }
                HoldButton(title: "OPTIONS") { pressed in gamepadState.set(.options, pressed: pressed) }
            }

            VStack(spacing: 5) {
                Text("BLE HID experimental")
                    .font(.caption.bold())
                Text("Some hosts may reject iOS peripheral HID. Works best for testing report flow first.")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .frame(width: 160)
    }

    private var rightController: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = min(proxy.size.width, proxy.size.height) * 0.25
            ZStack {
                ActionButton(title: "△") { pressed in gamepadState.set(.triangle, pressed: pressed) }
                    .position(x: center.x, y: center.y - radius)

                ActionButton(title: "×") { pressed in gamepadState.set(.cross, pressed: pressed) }
                    .position(x: center.x, y: center.y + radius)

                ActionButton(title: "□") { pressed in gamepadState.set(.square, pressed: pressed) }
                    .position(x: center.x - radius, y: center.y)

                ActionButton(title: "○") { pressed in gamepadState.set(.circle, pressed: pressed) }
                    .position(x: center.x + radius, y: center.y)

                VStack {
                    HStack {
                        HoldButton(title: "L1") { pressed in gamepadState.set(.l1, pressed: pressed) }
                        Spacer()
                        HoldButton(title: "R1") { pressed in gamepadState.set(.r1, pressed: pressed) }
                    }
                    Spacer()
                    HStack {
                        HoldButton(title: "L2") { pressed in gamepadState.set(.l2, pressed: pressed) }
                        Spacer()
                        HoldButton(title: "R2") { pressed in gamepadState.set(.r2, pressed: pressed) }
                    }
                }
                .padding(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var directionLabels: [(label: String, angle: CGFloat, radius: CGFloat, primary: Bool)] {
        [
            ("W", -.pi / 2, 0.34, true),
            ("D", 0, 0.34, true),
            ("S", .pi / 2, 0.34, true),
            ("A", .pi, 0.34, true),
            ("WD", -.pi / 4, 0.31, false),
            ("DS", .pi / 4, 0.31, false),
            ("AS", .pi * 0.75, 0.31, false),
            ("AW", -.pi * 0.75, 0.31, false),
            ("WS", .pi / 2, 0.13, false),
            ("AD", 0, 0.13, false)
        ]
    }
}

struct ActionButton: View {
    let title: String
    let onPress: (Bool) -> Void

    var body: some View {
        Text(title)
            .font(.system(size: 38, weight: .bold, design: .rounded))
            .frame(width: 82, height: 82)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 2))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress(true) }
                    .onEnded { _ in onPress(false) }
            )
    }
}

struct HoldButton: View {
    let title: String
    let onPress: (Bool) -> Void

    var body: some View {
        Text(title)
            .font(.caption.bold())
            .frame(width: 74, height: 36)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress(true) }
                    .onEnded { _ in onPress(false) }
            )
    }
}
