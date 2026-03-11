import Foundation
import IOKit
import IOKit.serial
import Combine
import SwiftUI

// Hardware event types
enum HardwareEvent {
    case encoderCW
    case encoderCCW
    case encoderClick
    case buttonAI
    case buttonHome
    case buttonEject
}

class HardwareService: ObservableObject {
    static let shared = HardwareService()

    @Published var isConnected = false
    @Published var encoderPosition: Int = 0
    @Published var buttonStates: [Bool] = Array(repeating: false, count: 4)
    @Published var ledBrightness: Double = 0.5

    private var serialPort: FileHandle?
    private var devicePath: String?
    private var cancellables = Set<AnyCancellable>()
    private var monitoringTimer: Timer?
    private var eventCallbacks: [String: (HardwareEvent) -> Void] = [:]
    private var isPolling = false
    private let serialQueue = DispatchQueue(label: "com.tome.hardware.serial", qos: .userInteractive)

    // Protocol constants (matching Arduino firmware)
    private enum Command: UInt8 {
        case ping = 0x01
        case getEncoder = 0x02
        case getButtons = 0x03
        case setLED = 0x04
        case getEvents = 0x05
        case getPhoneStatus = 0x06
        case setEnvironment = 0x07
        case ejectPhone = 0x08
        case setMotorSpeed = 0x09
    }

    private enum Response: UInt8 {
        case pong = 0x81
        case encoder = 0x82
        case buttons = 0x83
        case ledAck = 0x84
        case events = 0x85
        case phoneStatus = 0x86
        case envAck = 0x87
        case ejectAck = 0x88
        case motorSpeedAck = 0x89
    }

    private enum EventType: UInt8 {
        case encoderCW = 0x01
        case encoderCCW = 0x02
        case encoderClick = 0x03
        case buttonAI = 0x04
        case buttonHome = 0x05
        case buttonEject = 0x06
    }
    
    private init() {
        startDeviceMonitoring()
    }
    
    deinit {
        disconnect()
        stopDeviceMonitoring()
    }
    
    // MARK: - Device Discovery and Connection
    
    private func startDeviceMonitoring() {
        // Check for devices every 5 seconds on background queue
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            DispatchQueue.global(qos: .background).async {
                self?.scanForDevices()
            }
        }

        // Initial scan - async to not block init
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.scanForDevices()
        }
    }
    
    private func stopDeviceMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    private func scanForDevices() {
        guard !isConnected else { return }

        print("🔍 Scanning for TOME hardware devices...")
        let devicePaths = findArduinoDevices()
        print("🔍 Found \(devicePaths.count) potential devices: \(devicePaths)")

        for path in devicePaths {
            print("🔌 Attempting connection to: \(path)")
            if attemptConnection(to: path) {
                devicePath = path
                isConnected = true
                startDataPolling()
                print("✅ Connected to TOME hardware at: \(path)")
                break
            } else {
                print("❌ Failed to connect to: \(path)")
            }
        }

        if !isConnected {
            print("⚠️ No TOME hardware devices found")
        }
    }
    
    private func findArduinoDevices() -> [String] {
        var devices: [String] = []

        // Comprehensive list of USB serial device patterns
        // Both cu (callout) and tty (terminal) versions
        let patterns = [
            "/dev/cu.usbmodem*",    // Arduino Uno/Nano USB (callout)
            "/dev/tty.usbmodem*",   // Arduino Uno/Nano USB (terminal)
            "/dev/cu.usbserial*",   // FTDI-based devices (callout)
            "/dev/tty.usbserial*",  // FTDI-based devices (terminal)
            "/dev/cu.wchusbserial*", // CH340 chips (callout)
            "/dev/tty.wchusbserial*", // CH340 chips (terminal)
            "/dev/cu.SLAB_USBtoUART*", // Silicon Labs CP210x (callout)
            "/dev/tty.SLAB_USBtoUART*", // Silicon Labs CP210x (terminal)
        ]

        print("  🔎 Checking device patterns:")
        for pattern in patterns {
            print("    Pattern: \(pattern)")
            let task = Process()
            task.launchPath = "/bin/sh"
            task.arguments = ["-c", "ls \(pattern) 2>/dev/null"]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.launch()
            task.waitUntilExit()

            if let data = try? pipe.fileHandleForReading.readToEnd(),
               let output = String(data: data, encoding: .utf8) {
                let foundDevices = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: .newlines)
                    .filter { !$0.isEmpty }
                if !foundDevices.isEmpty {
                    print("      ✅ Found: \(foundDevices)")
                    devices.append(contentsOf: foundDevices)
                } else {
                    print("      ❌ No matches")
                }
            } else {
                print("      ❌ No matches")
            }
        }

        // Fallback: search entire /dev directory for any USB devices
        if devices.isEmpty {
            print("  🔎 Fallback: Searching all /dev for USB devices")
            let task = Process()
            task.launchPath = "/bin/sh"
            task.arguments = ["-c", "ls /dev/*usb* /dev/*USB* 2>/dev/null"]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.launch()
            task.waitUntilExit()

            if let data = try? pipe.fileHandleForReading.readToEnd(),
               let output = String(data: data, encoding: .utf8) {
                let foundDevices = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: .newlines)
                    .filter { !$0.isEmpty && ($0.contains("cu.") || $0.contains("tty.")) }
                if !foundDevices.isEmpty {
                    print("      ✅ Found via fallback: \(foundDevices)")
                    devices.append(contentsOf: foundDevices)
                } else {
                    print("      ❌ No USB devices found in /dev")
                }
            }
        }

        return devices
    }
    
    private func attemptConnection(to devicePath: String) -> Bool {
        print("  🔧 Opening device at path: \(devicePath)")
        guard let fileHandle = FileHandle(forUpdatingAtPath: devicePath) else {
            print("    ❌ Failed to open file handle")
            return false
        }

        // Configure serial port settings
        let fd = fileHandle.fileDescriptor
        var options = termios()

        if tcgetattr(fd, &options) != 0 {
            print("    ❌ Failed to get terminal attributes (errno: \(errno))")
            fileHandle.closeFile()
            return false
        }

        // Configure for 115200 baud, 8N1 (matching ESP8266)
        cfsetispeed(&options, speed_t(B115200))
        cfsetospeed(&options, speed_t(B115200))

        options.c_cflag = tcflag_t(CS8 | CREAD | CLOCAL)
        options.c_iflag = tcflag_t(0)
        options.c_oflag = tcflag_t(0)
        options.c_lflag = tcflag_t(0)

        // Non-blocking reads — deadline-based retry in readResponse handles timing
        options.c_cc.16 = 0  // VMIN = 0: return immediately even if no bytes
        options.c_cc.17 = 0  // VTIME = 0: no timeout, pure non-blocking

        if tcsetattr(fd, TCSANOW, &options) != 0 {
            print("    ❌ Failed to set terminal attributes (errno: \(errno))")
            fileHandle.closeFile()
            return false
        }

        print("    ✅ Serial port configured: 115200 8N1")
        serialPort = fileHandle

        // Test connection with ping - try multiple times as device may need to settle
        print("    🔄 Testing connection with ping (attempting 3 times)...")

        // Clear any startup junk from the buffer
        print("    🧹 Flushing startup data from buffer...")
        usleep(200000) // Wait 200ms for any startup messages
        tcflush(fd, TCIOFLUSH) // Flush both input and output buffers

        for attempt in 1...3 {
            usleep(150000) // Wait 150ms between attempts
            print("      Attempt \(attempt)/3")

            // Clear buffer before each ping
            tcflush(fd, TCIFLUSH)

            if sendPing() {
                print("    ✅ Connection verified via ping/pong")
                return true
            }

            // Read and display any junk in the buffer
            let maxJunkBytes = 100
            var junkBuffer = [UInt8](repeating: 0, count: maxJunkBytes)
            let bytesRead = read(fd, &junkBuffer, maxJunkBytes)
            if bytesRead > 0 {
                let junkData = Array(junkBuffer.prefix(bytesRead))
                print("        📋 Buffer contained \(bytesRead) unexpected bytes: \(junkData.prefix(20).map { String(format: "%02X", $0) }.joined(separator: " "))")
                if let junkStr = String(bytes: junkData, encoding: .ascii) {
                    print("        📋 As ASCII: \(junkStr.prefix(50))")
                }
            }
        }

        print("    ❌ All ping attempts failed")
        serialPort = nil
        fileHandle.closeFile()
        return false
    }
    
    func disconnect() {
        isConnected = false
        serialPort?.closeFile()
        serialPort = nil
        devicePath = nil
        stopDataPolling()
    }
    
    // MARK: - Communication Protocol
    
    private func sendCommand(_ command: Command, data: [UInt8] = []) -> Bool {
        guard let port = serialPort else {
            print("        ❌ No serial port available")
            return false
        }

        var packet = [UInt8]()
        packet.append(0xFF) // Start byte
        packet.append(command.rawValue)
        packet.append(UInt8(data.count))
        packet.append(contentsOf: data)

        // Calculate checksum
        let checksum = packet[1...].reduce(0) { $0 ^ $1 }
        packet.append(checksum)

        let packetData = Data(packet)

        do {
            try port.write(contentsOf: packetData)
            return true
        } catch {
            print("❌ Hardware: failed to send command: \(error)")
            handleConnectionError()
            return false
        }
    }
    
    /// Read a single byte from the serial fd, retrying until deadline.
    /// Returns nil if deadline passes with no byte.
    private func readByteWithDeadline(fd: Int32, deadline: Date) -> UInt8? {
        var byte: UInt8 = 0
        while Date() < deadline {
            let n = Darwin.read(fd, &byte, 1)
            if n == 1 { return byte }
            usleep(1_000) // 1ms back-off
        }
        return nil
    }

    /// Read a complete response packet with a deadline.
    /// Scans for the 0xFF start byte (skipping any debug text / stale ACKs),
    /// then reads the header, payload, and checksum.
    private func readResponse(timeout: TimeInterval = 0.08) -> (Response?, [UInt8])? {
        guard let port = serialPort else { return nil }
        let fd = port.fileDescriptor
        let deadline = Date().addingTimeInterval(timeout)

        // Scan for 0xFF start byte — skip up to 100 bytes of garbage/debug
        var foundStart = false
        for _ in 0..<100 {
            guard let byte = readByteWithDeadline(fd: fd, deadline: deadline) else { break }
            if byte == 0xFF { foundStart = true; break }
        }
        guard foundStart else { return nil }

        // Read response code + data length
        guard let code = readByteWithDeadline(fd: fd, deadline: deadline),
              let length = readByteWithDeadline(fd: fd, deadline: deadline) else { return nil }

        // Read payload
        var data = [UInt8]()
        data.reserveCapacity(Int(length))
        for _ in 0..<Int(length) {
            guard let byte = readByteWithDeadline(fd: fd, deadline: deadline) else { return nil }
            data.append(byte)
        }

        // Read checksum
        guard let receivedChecksum = readByteWithDeadline(fd: fd, deadline: deadline) else { return nil }

        // Verify checksum
        var calc: UInt8 = code ^ length
        for b in data { calc ^= b }
        guard calc == receivedChecksum else { return nil }

        guard let response = Response(rawValue: code) else { return nil }
        return (response, data)
    }
    
    private func sendPing() -> Bool {
        print("  📤 Sending ping...")
        guard sendCommand(.ping) else {
            print("  ❌ Failed to send ping command")
            return false
        }

        if let (response, _) = readResponse(timeout: 0.2), response == .pong {
            print("  ✅ Received pong response")
            return true
        }

        print("  ❌ No pong response received")
        return false
    }
    
    private func handleConnectionError() {
        print("Hardware connection error detected")
        disconnect()
    }
    
    // MARK: - Data Polling

    private func startDataPolling() {
        isPolling = true
        pollNext()
    }

    // Recursive asyncAfter loop — schedules the next poll only after the
    // current one finishes, so there's no queue buildup and no RunLoop dependency.
    private func pollNext() {
        serialQueue.asyncAfter(deadline: .now() + .milliseconds(20)) { [weak self] in
            guard let self, self.isPolling else { return }
            if self.isConnected { self.updateEvents() }
            self.pollNext()
        }
    }

    private func stopDataPolling() {
        isPolling = false
        cancellables.removeAll()
    }

    private func pollHardwareState() {
        guard isConnected else { return }

        updateEvents()
    }

    private func updateEvents() {
        guard sendCommand(.getEvents) else { return }

        if let (response, data) = readResponse(), response == .events {
            let eventCount = data.count / 3
            for i in 0..<eventCount {
                let offset = i * 3
                guard offset + 2 < data.count else { continue }
                let eventType = data[offset]
                let value = Int16(bitPattern: UInt16(data[offset + 1]) << 8 | UInt16(data[offset + 2]))
                processEvent(eventType: eventType, value: value)
            }
            // ESP32 caps responses at 5 events — if we hit the cap there may
            // be more queued, so drain immediately rather than waiting 20ms
            if eventCount >= 5 {
                updateEvents()
            }
        }
    }

    private func processEvent(eventType: UInt8, value: Int16) {
        guard let type = EventType(rawValue: eventType) else {
            print("⚠️ Unknown event type: \(eventType)")
            return
        }

        DispatchQueue.main.async {
            switch type {
            case .encoderCW:
                self.encoderPosition = Int(value)
                self.notifyEventCallbacks(.encoderCW)

            case .encoderCCW:
                self.encoderPosition = Int(value)
                self.notifyEventCallbacks(.encoderCCW)

            case .encoderClick:
                print("🔘 Encoder click detected")
                self.notifyEventCallbacks(.encoderClick)

            case .buttonAI:
                print("🤖 AI button event detected in HardwareService")
                self.notifyEventCallbacks(.buttonAI)

            case .buttonHome:
                print("🏠 Home button event detected")
                self.notifyEventCallbacks(.buttonHome)

            case .buttonEject:
                print("📱 Eject button event detected")
                self.notifyEventCallbacks(.buttonEject)
            }
        }
    }
    
    
    // MARK: - Hardware Control

    func setLEDBrightness(_ brightness: Double) {
        let clampedBrightness = max(0.0, min(1.0, brightness))
        let brightnessValue = UInt8(clampedBrightness * 255)

        if sendCommand(.setLED, data: [brightnessValue]) {
            DispatchQueue.main.async {
                self.ledBrightness = clampedBrightness
            }
        }
    }

    func setEnvironment(_ environment: TOMEEnvironment) {
        guard isConnected else { return }

        let envId: UInt8 = {
            switch environment {
            case .home: return 0
            case .planning: return 1
            case .writerDesk: return 2
            case .workshop: return 3
            case .coffeeshop: return 4
            case .garden: return 5
            }
        }()

        // Dispatch onto the serial queue so this doesn't race with poll timer.
        // Also consume the envAck so it doesn't pollute the next event read.
        serialQueue.async { [weak self] in
            guard let self else { return }
            if self.sendCommand(.setEnvironment, data: [envId]) {
                _ = self.readResponse() // consume envAck
            }
        }
    }
    
    
    // MARK: - Event Handling

    func onEvent(id: String, _ handler: @escaping (HardwareEvent) -> Void) {
        eventCallbacks[id] = handler
    }

    private func notifyEventCallbacks(_ event: HardwareEvent) {
        for (_, callback) in eventCallbacks {
            callback(event)
        }
    }

    func removeEventCallback(id: String) {
        eventCallbacks.removeValue(forKey: id)
    }

    func clearEventCallbacks() {
        eventCallbacks.removeAll()
    }
    
    // MARK: - Utility Methods
    
    func getConnectionInfo() -> String {
        if isConnected, let path = devicePath {
            return "Connected: \(path)"
        } else {
            return "Disconnected"
        }
    }
    
    func testConnection() -> Bool {
        return sendPing()
    }
}

// MARK: - Supporting Types

enum LEDPattern {
    case solid(brightness: Double)
    case pulse(speed: Double)
    case breathe(intensity: Double)
    case rainbow(speed: Double)
    case environmentColor(TOMEEnvironment)
}

// MARK: - Extensions

extension SwiftUI.Color {
    static func == (lhs: SwiftUI.Color, rhs: SwiftUI.Color) -> Bool {
        // Simplified comparison - in practice you'd need more sophisticated color comparison
        return true
    }
}