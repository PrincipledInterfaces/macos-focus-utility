import Foundation
import SwiftUI

/// Manages the TOME ambient light strip (ESP32 light controller).
/// Uses a plain-text serial protocol distinct from the binary protocol
/// used by HardwareService for the TOME controller board.
class LightControllerService: ObservableObject {
    static let shared = LightControllerService()

    @Published var isConnected = false

    private var serialPort: FileHandle?
    private var monitoringTimer: Timer?

    // MARK: - Environment Palettes

    /// Multi-stop gradients for each environment. The ESP32 smoothly
    /// crossfades between them automatically when a new command is sent.
    private let palettes: [TOMEEnvironment: [String]] = [
        .home:       ["#fffaf0", "#ffffff", "#ffe9cc", "#ffffff"],
        .planning:   ["#0040ff", "#0099ff", "#00d4ff", "#0066cc"],
        .writerDesk: ["#00c853", "#00e676", "#1de9b6", "#00acc1"],
        .workshop:   ["#7c4dff", "#aa00ff", "#e040fb", "#b388ff"],
        .coffeeshop: ["#ff6d00", "#ff8f00", "#ffc400", "#ff6f00"],
        .garden:     ["#00e676", "#69f0ae", "#b9f6ca", "#43a047"],
    ]

    private init() {
        // Slight delay so HardwareService gets first pick of ports
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.scanForDevices()
        }
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            DispatchQueue.global(qos: .background).async { self?.scanForDevices() }
        }
    }

    deinit {
        monitoringTimer?.invalidate()
        serialPort?.closeFile()
    }

    // MARK: - Device Discovery

    private func scanForDevices() {
        guard !isConnected else { return }

        let patterns = [
            "/dev/cu.usbmodem*",
            "/dev/tty.usbmodem*",
            "/dev/cu.usbserial*",
            "/dev/tty.usbserial*",
            "/dev/cu.wchusbserial*",
            "/dev/tty.wchusbserial*",
            "/dev/cu.SLAB_USBtoUART*",
            "/dev/tty.SLAB_USBtoUART*",
        ]

        var devices: [String] = []
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
                devices.append(contentsOf:
                    output.trimmingCharacters(in: .whitespacesAndNewlines)
                          .components(separatedBy: .newlines)
                          .filter { !$0.isEmpty }
                )
            }
        }

        for device in devices {
            if attemptConnection(to: device) {
                DispatchQueue.main.async { self.isConnected = true }
                print("💡 Light controller connected at: \(device)")
                return
            }
        }
    }

    // MARK: - Connection

    private func attemptConnection(to path: String) -> Bool {
        guard let fileHandle = FileHandle(forUpdatingAtPath: path) else { return false }

        let fd = fileHandle.fileDescriptor
        var options = termios()
        guard tcgetattr(fd, &options) == 0 else { fileHandle.closeFile(); return false }

        cfsetispeed(&options, speed_t(B115200))
        cfsetospeed(&options, speed_t(B115200))
        options.c_cflag = tcflag_t(CS8 | CREAD | CLOCAL)
        options.c_iflag = 0
        options.c_oflag = 0
        options.c_lflag = 0
        options.c_cc.16 = 0   // VMIN = 0 — non-blocking reads
        options.c_cc.17 = 5   // VTIME = 0.5 s per read attempt

        guard tcsetattr(fd, TCSANOW, &options) == 0 else { fileHandle.closeFile(); return false }

        serialPort = fileHandle

        // Give the device time to settle, then flush any startup junk
        usleep(600_000)
        tcflush(fd, TCIOFLUSH)

        // First check: device may have already announced itself on power-up
        // Read whatever is waiting in the buffer
        var announced = false
        let buffered = readTextLine(fd: fd, timeout: 0.5)
        if buffered.contains("TOME_LIGHT_CONTROLLER_V1") {
            announced = true
        }

        if !announced {
            // Actively ask the device to identify itself
            writeLine("TOME_IDENTIFY", fd: fd)
            usleep(300_000)
            let response = readTextLine(fd: fd, timeout: 1.0)
            if !response.contains("TOME_LIGHT_CONTROLLER_V1") {
                serialPort = nil
                fileHandle.closeFile()
                return false
            }
        }

        return true
    }

    // MARK: - Public API

    func setEnvironment(_ environment: TOMEEnvironment) {
        guard let colors = palettes[environment] else { return }
        let cmd = "l:(\(colors.joined(separator: ", ")))"
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self, let handle = self.serialPort else { return }
            self.writeLine(cmd, fd: handle.fileDescriptor)
        }
    }

    // MARK: - Serial Helpers

    private func writeLine(_ text: String, fd: Int32) {
        let line = text + "\n"
        guard let data = line.data(using: .utf8) else { return }
        data.withUnsafeBytes { ptr in
            _ = Darwin.write(fd, ptr.baseAddress!, data.count)
        }
    }

    /// Reads one text line from the serial fd, waiting at most `timeout` seconds.
    private func readTextLine(fd: Int32, timeout: TimeInterval) -> String {
        var line = ""
        var byte: UInt8 = 0
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let n = Darwin.read(fd, &byte, 1)
            if n == 1 {
                if byte == UInt8(ascii: "\n") || byte == UInt8(ascii: "\r") {
                    if !line.isEmpty { return line }
                } else {
                    line.append(Character(UnicodeScalar(byte)))
                }
            } else {
                usleep(5_000) // 5 ms back-off before retrying
            }
        }
        return line
    }
}
