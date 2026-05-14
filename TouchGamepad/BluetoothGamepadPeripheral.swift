import Foundation
import CoreBluetooth
import Combine

final class BluetoothGamepadPeripheral: NSObject, ObservableObject {
    @Published private(set) var status: String = "Bluetooth permission needed"
    @Published private(set) var isAdvertising = false
    @Published private(set) var connectedCentrals = 0

    private let state: GamepadState
    private var cancellables = Set<AnyCancellable>()
    private var peripheralManager: CBPeripheralManager?
    private var inputReportCharacteristic: CBMutableCharacteristic?
    private var subscribedCentrals: [CBCentral] = []

    private let hidServiceUUID = CBUUID(string: "1812")
    private let reportMapUUID = CBUUID(string: "2A4B")
    private let hidInformationUUID = CBUUID(string: "2A4A")
    private let inputReportUUID = CBUUID(string: "2A4D")
    private let protocolModeUUID = CBUUID(string: "2A4E")

    init(state: GamepadState) {
        self.state = state
        super.init()

        state.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) {
                    self?.sendCurrentReport()
                }
            }
            .store(in: &cancellables)
    }

    func requestBluetoothAndStart() {
        if peripheralManager == nil {
            peripheralManager = CBPeripheralManager(delegate: self, queue: .main)
        } else {
            configureIfPossible()
        }
    }

    private func configureIfPossible() {
        guard let peripheralManager else { return }
        switch peripheralManager.state {
        case .poweredOn:
            status = "Bluetooth on. Advertising experimental BLE gamepad."
            setupService()
        case .poweredOff:
            status = "Bluetooth is turned off"
        case .unauthorized:
            status = "Bluetooth permission denied"
        case .unsupported:
            status = "BLE peripheral mode unsupported on this device"
        case .resetting:
            status = "Bluetooth resetting"
        case .unknown:
            status = "Bluetooth state unknown"
        @unknown default:
            status = "Bluetooth unavailable"
        }
    }

    private func setupService() {
        guard let peripheralManager else { return }
        peripheralManager.removeAllServices()

        let reportMap = CBMutableCharacteristic(
            type: reportMapUUID,
            properties: [.read],
            value: Self.gamepadReportMap,
            permissions: [.readable]
        )

        let hidInformation = CBMutableCharacteristic(
            type: hidInformationUUID,
            properties: [.read],
            value: Data([0x11, 0x01, 0x00, 0x02]),
            permissions: [.readable]
        )

        let protocolMode = CBMutableCharacteristic(
            type: protocolModeUUID,
            properties: [.read, .writeWithoutResponse],
            value: Data([0x01]),
            permissions: [.readable, .writeable]
        )

        let reportReference = CBMutableDescriptor(
            type: CBUUID(string: "2908"),
            value: Data([0x01, 0x01])
        )

        let input = CBMutableCharacteristic(
            type: inputReportUUID,
            properties: [.read, .notify],
            value: nil,
            permissions: [.readable]
        )
        input.descriptors = [reportReference]
        inputReportCharacteristic = input

        let service = CBMutableService(type: hidServiceUUID, primary: true)
        service.characteristics = [hidInformation, reportMap, protocolMode, input]
        peripheralManager.add(service)
    }

    private func startAdvertising() {
        guard let peripheralManager, !peripheralManager.isAdvertising else { return }
        peripheralManager.startAdvertising([
            CBAdvertisementDataLocalNameKey: "Touch Gamepad",
            CBAdvertisementDataServiceUUIDsKey: [hidServiceUUID]
        ])
        isAdvertising = true
    }

    private func sendCurrentReport() {
        guard let peripheralManager, let inputReportCharacteristic, !subscribedCentrals.isEmpty else { return }
        let success = peripheralManager.updateValue(
            state.report,
            for: inputReportCharacteristic,
            onSubscribedCentrals: subscribedCentrals
        )
        status = success ? "Sending touch input over BLE" : "BLE transmit queue full"
    }

    static let gamepadReportMap = Data([
        0x05, 0x01,       // Usage Page Generic Desktop
        0x09, 0x05,       // Usage Game Pad
        0xA1, 0x01,       // Collection Application
        0x85, 0x01,       // Report ID 1
        0x09, 0x30,       // Usage X
        0x09, 0x31,       // Usage Y
        0x09, 0x33,       // Usage Rx
        0x09, 0x34,       // Usage Ry
        0x15, 0x00,       // Logical Min 0
        0x26, 0xFF, 0x00, // Logical Max 255
        0x75, 0x08,       // Report Size 8
        0x95, 0x04,       // Report Count 4
        0x81, 0x02,       // Input Data Var Abs
        0x05, 0x01,       // Usage Page Generic Desktop
        0x09, 0x39,       // Usage Hat switch
        0x15, 0x00,       // Logical Min 0
        0x25, 0x08,       // Logical Max 8
        0x35, 0x00,       // Physical Min 0
        0x46, 0x3B, 0x01, // Physical Max 315
        0x65, 0x14,       // Unit Eng Rot Degrees
        0x75, 0x08,       // Report Size 8
        0x95, 0x01,       // Report Count 1
        0x81, 0x02,       // Input Data Var Abs
        0x05, 0x09,       // Usage Page Button
        0x19, 0x01,       // Usage Min Button 1
        0x29, 0x10,       // Usage Max Button 16
        0x15, 0x00,       // Logical Min 0
        0x25, 0x01,       // Logical Max 1
        0x75, 0x01,       // Report Size 1
        0x95, 0x10,       // Report Count 16
        0x81, 0x02,       // Input Data Var Abs
        0xC0              // End Collection
    ])
}

extension BluetoothGamepadPeripheral: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        configureIfPossible()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error {
            status = "Failed to add BLE service: \(error.localizedDescription)"
            return
        }
        startAdvertising()
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error {
            status = "Advertising failed: \(error.localizedDescription)"
            isAdvertising = false
        } else {
            status = "Ready. Pair from another device as Touch Gamepad."
            isAdvertising = true
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        if !subscribedCentrals.contains(where: { $0.identifier == central.identifier }) {
            subscribedCentrals.append(central)
        }
        connectedCentrals = subscribedCentrals.count
        status = "Connected: \(connectedCentrals)"
        sendCurrentReport()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        subscribedCentrals.removeAll { $0.identifier == central.identifier }
        connectedCentrals = subscribedCentrals.count
        status = subscribedCentrals.isEmpty ? "Advertising experimental BLE gamepad" : "Connected: \(connectedCentrals)"
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        if request.characteristic.uuid == inputReportUUID {
            request.value = state.report
            peripheral.respond(to: request, withResult: .success)
        } else {
            peripheral.respond(to: request, withResult: .requestNotSupported)
        }
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        sendCurrentReport()
    }
}
