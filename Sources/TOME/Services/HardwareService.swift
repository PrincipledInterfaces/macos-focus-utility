import Foundation
import IOKit
import IOKit.serial
import Combine
import SwiftUI

class HardwareService: ObservableObject {
    @Published var isConnected = false
    @Published var dialPosition: Double = 0.0
    @Published var buttonStates: [Bool] = Array(repeating: false, count: 4)
    @Published var ledBrightness: Double = 0.5
    
    private var serialPort: FileHandle?
    private var devicePath: String?
    private var cancellables = Set<AnyCancellable>()
    private var monitoringTimer: Timer?
    
    // Protocol constants (matching Arduino firmware)
    private enum Command: UInt8 {
        case ping = 0x01
        case getDial = 0x02
        case getButtons = 0x03
        case setLED = 0x04
        case setLEDPattern = 0x05
        case getStatus = 0x06
    }
    
    private enum Response: UInt8 {
        case pong = 0x81
        case dialPosition = 0x82
        case buttonStates = 0x83
        case ledAck = 0x84
        case statusData = 0x86
    }
    
    init() {
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
        
        // Initial scan
        scanForDevices()
    }
    
    private func stopDeviceMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    private func scanForDevices() {
        guard !isConnected else { return }
        
        let devicePaths = findArduinoDevices()
        
        for path in devicePaths {
            if attemptConnection(to: path) {
                devicePath = path
                isConnected = true
                startDataPolling()
                print("Connected to TOME hardware at: \(path)")
                break
            }
        }
    }
    
    private func findArduinoDevices() -> [String] {
        var devices: [String] = []
        
        // Common Arduino USB device patterns
        let patterns = [
            "/dev/cu.usbmodem*",    // Arduino Uno/Nano USB
            "/dev/cu.usbserial*",   // Arduino with FTDI
            "/dev/cu.wchusbserial*" // CH340 based Arduinos
        ]
        
        for pattern in patterns {
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
                devices.append(contentsOf: foundDevices)
            }
        }
        
        return devices
    }
    
    private func attemptConnection(to devicePath: String) -> Bool {
        guard let fileHandle = FileHandle(forUpdatingAtPath: devicePath) else {
            return false
        }
        
        // Configure serial port settings
        let fd = fileHandle.fileDescriptor
        var options = termios()
        
        if tcgetattr(fd, &options) != 0 {
            fileHandle.closeFile()
            return false
        }
        
        // Configure for 9600 baud, 8N1
        cfsetispeed(&options, speed_t(B9600))
        cfsetospeed(&options, speed_t(B9600))
        
        options.c_cflag = tcflag_t(CS8 | CREAD | CLOCAL)
        options.c_iflag = tcflag_t(0)
        options.c_oflag = tcflag_t(0)
        options.c_lflag = tcflag_t(0)
        
        // Set read timeout
        options.c_cc.16 = 1  // VMIN
        options.c_cc.17 = 10 // VTIME (1 second timeout)
        
        if tcsetattr(fd, TCSANOW, &options) != 0 {
            fileHandle.closeFile()
            return false
        }
        
        serialPort = fileHandle
        
        // Test connection with ping
        usleep(100000) // Wait 100ms for Arduino to initialize
        return sendPing()
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
        guard let port = serialPort else { return false }
        
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
            print("Failed to send command: \(error)")
            handleConnectionError()
            return false
        }
    }
    
    private func readResponse() -> (Response?, [UInt8])? {
        guard let port = serialPort else { return nil }
        
        do {
            // Read start byte
            let startData = try port.read(upToCount: 1)
            guard let startByte = startData?.first, startByte == 0xFF else { return nil }
            
            // Read command and length
            let headerData = try port.read(upToCount: 2)
            guard let header = headerData, header.count == 2 else { return nil }
            
            let responseCode = header[0]
            let dataLength = header[1]
            
            // Read data and checksum
            let remainingLength = Int(dataLength) + 1 // +1 for checksum
            let remainingData = try port.read(upToCount: remainingLength)
            guard let remaining = remainingData, remaining.count == remainingLength else { return nil }
            
            let data = Array(remaining.prefix(Int(dataLength)))
            let receivedChecksum = remaining.last!
            
            // Verify checksum
            var calculatedChecksum: UInt8 = responseCode ^ dataLength
            for byte in data {
                calculatedChecksum ^= byte
            }
            
            guard calculatedChecksum == receivedChecksum else {
                print("Checksum mismatch")
                return nil
            }
            
            guard let response = Response(rawValue: responseCode) else { return nil }
            return (response, data)
            
        } catch {
            print("Failed to read response: \(error)")
            handleConnectionError()
            return nil
        }
    }
    
    private func sendPing() -> Bool {
        guard sendCommand(.ping) else { return false }
        
        usleep(50000) // Wait 50ms for response
        
        if let (response, _) = readResponse(), response == .pong {
            return true
        }
        
        return false
    }
    
    private func handleConnectionError() {
        print("Hardware connection error detected")
        disconnect()
    }
    
    // MARK: - Data Polling
    
    private func startDataPolling() {
        // Poll hardware state every 500ms on background queue
        Timer.publish(every: 0.5, on: RunLoop.main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                DispatchQueue.global(qos: .utility).async {
                    self?.pollHardwareState()
                }
            }
            .store(in: &cancellables)
    }
    
    private func stopDataPolling() {
        cancellables.removeAll()
    }
    
    private func pollHardwareState() {
        guard isConnected else { return }
        
        updateDialPosition()
        updateButtonStates()
    }
    
    private func updateDialPosition() {
        guard sendCommand(.getDial) else { return }
        
        usleep(10000) // Wait 10ms for response
        
        if let (response, data) = readResponse(),
           response == .dialPosition,
           data.count >= 2 {
            let rawValue = UInt16(data[0]) << 8 | UInt16(data[1])
            let normalizedValue = Double(rawValue) / 1023.0 // Assuming 10-bit ADC
            
            DispatchQueue.main.async {
                self.dialPosition = normalizedValue
            }
        }
    }
    
    private func updateButtonStates() {
        guard sendCommand(.getButtons) else { return }
        
        usleep(10000) // Wait 10ms for response
        
        if let (response, data) = readResponse(),
           response == .buttonStates,
           data.count >= 1 {
            let buttonBits = data[0]
            var newStates: [Bool] = []
            
            for i in 0..<4 {
                newStates.append((buttonBits & (1 << i)) != 0)
            }
            
            DispatchQueue.main.async {
                self.buttonStates = newStates
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
    
    func setLEDPattern(_ pattern: LEDPattern) {
        let patternData: [UInt8]
        
        switch pattern {
        case .solid(let brightness):
            patternData = [0x01, UInt8(brightness * 255)]
        case .pulse(let speed):
            patternData = [0x02, UInt8(speed * 255)]
        case .breathe(let intensity):
            patternData = [0x03, UInt8(intensity * 255)]
        case .rainbow(let speed):
            patternData = [0x04, UInt8(speed * 255)]
        case .environmentColor(let environment):
            let color = environment.primaryColor
            patternData = [0x05, colorToRGB(color)]
        }
        
        _ = sendCommand(.setLEDPattern, data: patternData)
    }
    
    private func colorToRGB(_ color: Color) -> UInt8 {
        // Simplified color to single byte conversion
        // In a real implementation, you'd want full RGB values
        switch color {
        case .blue: return 0x01
        case .green: return 0x02
        case .purple: return 0x03
        case .orange: return 0x04
        default: return 0x00
        }
    }
    
    // MARK: - Event Handling
    
    func onDialChanged(_ handler: @escaping (Double) -> Void) {
        $dialPosition
            .removeDuplicates()
            .sink(receiveValue: handler)
            .store(in: &cancellables)
    }
    
    func onButtonPressed(_ buttonIndex: Int, _ handler: @escaping () -> Void) {
        $buttonStates
            .map { $0[safe: buttonIndex] ?? false }
            .removeDuplicates()
            .filter { $0 } // Only trigger on press (true)
            .sink { _ in handler() }
            .store(in: &cancellables)
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

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension SwiftUI.Color {
    static func == (lhs: SwiftUI.Color, rhs: SwiftUI.Color) -> Bool {
        // Simplified comparison - in practice you'd need more sophisticated color comparison
        return true
    }
}