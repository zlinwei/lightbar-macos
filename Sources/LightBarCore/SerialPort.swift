// SPDX-License-Identifier: GPL-3.0-only
import Foundation
import Darwin

/// Serial descriptor has one owner; reads and writes are serialized on this actor.
public actor SerialPort {
    private var descriptor: Int32 = -1
    private var original: termios?
    public init() {}
    deinit { if descriptor >= 0 { Darwin.close(descriptor) } }
    public static func ports() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath:"/dev")) ?? [])
            .filter { $0.hasPrefix("cu.") && !$0.contains("Bluetooth") && !$0.contains("debug-console") }
            .sorted().map { "/dev/" + $0 }
    }
    public func connect(path: String) throws {
        guard descriptor < 0 else { throw ModuleError.busy }
        guard path.hasPrefix("/dev/cu."), !path.dropFirst(5).contains("/"), !path.utf8.contains(0) else { throw ModuleError.system("无效串口路径。") }
        let fd = Darwin.open(path, O_RDWR | O_NOCTTY | O_NONBLOCK | O_NOFOLLOW)
        guard fd >= 0 else { throw lastError("打开串口") }
        do {
            var metadata = stat()
            guard fstat(fd, &metadata) == 0 else { throw lastError("检查串口设备") }
            guard metadata.st_mode & mode_t(S_IFMT) == mode_t(S_IFCHR) else { throw ModuleError.system("目标不是字符设备。") }
            guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { throw ModuleError.busy }
            guard ioctl(fd, TIOCEXCL) == 0 else { throw lastError("独占串口") }
            var settings = termios()
            guard tcgetattr(fd, &settings) == 0 else { throw lastError("读取串口设置") }
            let saved = settings
            cfmakeraw(&settings)
            settings.c_cflag &= ~tcflag_t(PARENB | CSTOPB | CSIZE | CRTSCTS)
            settings.c_cflag |= tcflag_t(CS8 | CLOCAL | CREAD)
            cfsetispeed(&settings, speed_t(B115200)); cfsetospeed(&settings, speed_t(B115200))
            guard tcsetattr(fd, TCSANOW, &settings) == 0 else { throw lastError("设置 115200 8N1") }
            descriptor = fd; original = saved
        } catch { _ = ioctl(fd, TIOCNXCL); Darwin.close(fd); throw error }
    }
    public func disconnect() {
        guard descriptor >= 0 else { return }
        if var saved = original { _ = tcsetattr(descriptor, TCSANOW, &saved) }
        _ = ioctl(descriptor, TIOCNXCL); _ = flock(descriptor, LOCK_UN)
        Darwin.close(descriptor); descriptor = -1; original = nil
    }
    public func exchange(_ data: Data, waitMilliseconds: Int = 400) throws -> Data {
        guard descriptor >= 0 else { throw ModuleError.notConnected }
        try Task.checkCancellation()
        try writeAll(data)
        return try receive(milliseconds: waitMilliseconds)
    }
    /// Each 17-byte command is a separate serial frame (>10ms silence required).
    public func transmit(packets: [Data], repetitions: Int) throws -> [Data] {
        guard (1...30).contains(repetitions) else { throw ModuleError.system("重复次数必须在 1…30 之间。") }
        guard descriptor >= 0 else { throw ModuleError.notConnected }
        var replies: [Data] = []
        for packet in packets {
            for _ in 0..<repetitions {
                try Task.checkCancellation()
                try writeAll(packet)
                let response = try receive(milliseconds:25)
                if !response.isEmpty { replies.append(response) }
            }
        }
        return replies
    }
    private func writeAll(_ data: Data) throws {
        let deadline = Date().addingTimeInterval(1)
        try data.withUnsafeBytes { buffer in
            var offset = 0
            while offset < data.count {
                try Task.checkCancellation()
                guard Date() < deadline else { throw ModuleError.writeTimeout }
                let count = Darwin.write(descriptor,buffer.baseAddress!.advanced(by:offset),data.count-offset)
                if count > 0 { offset += count }
                else if count < 0 && errno != EAGAIN && errno != EINTR { throw lastError("写入串口") }
                else { usleep(1000) }
            }
        }
        // Do not block indefinitely in tcdrain on unplug; the following receive
        // interval provides >10ms frame separation at 115200 for our small frames.
    }
    private func receive(milliseconds: Int) throws -> Data {
        let deadline = Date().addingTimeInterval(Double(milliseconds)/1000)
        var result = Data(); var buffer = [UInt8](repeating:0,count:2048)
        while Date() < deadline {
            try Task.checkCancellation()
            var event = pollfd(fd:descriptor,events:Int16(POLLIN),revents:0)
            let ready = poll(&event,1,10)
            if ready < 0 && errno != EINTR { throw lastError("读取串口") }
            if event.revents & Int16(POLLHUP | POLLERR | POLLNVAL) != 0 { throw ModuleError.system("串口已断开或发生 I/O 错误。") }
            if ready > 0 && event.revents & Int16(POLLIN) != 0 {
                let count = Darwin.read(descriptor,&buffer,buffer.count)
                if count > 0 {
                    guard result.count + count <= 64*1024 else { throw ModuleError.system("模块响应超过 64 KiB，已停止读取。") }
                    result.append(contentsOf:buffer.prefix(count))
                } else if count < 0 && errno != EAGAIN && errno != EINTR { throw lastError("读取串口") }
            }
        }
        return result
    }
    private func lastError(_ operation: String) -> ModuleError { .system("\(operation)：\(String(cString:strerror(errno)))") }
}
