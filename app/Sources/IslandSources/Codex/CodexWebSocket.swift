import CryptoKit
import Darwin
import Foundation

/// WebSocket поверх сокета существующего daemon. Все операции принадлежат одной очереди.
final class CodexWebSocket: @unchecked Sendable {
  enum Event: Sendable {
    case opened
    case message(Data)
    case closed(String)
  }
  private let queue = DispatchQueue(label: "dev.nikoko.oasis.codex.socket")
  private let callback: @Sendable (Event) -> Void
  private var descriptor: Int32 = -1
  private var reader: DispatchSourceRead?
  private var writer: DispatchSourceWrite?
  private var input = Data()
  private var output = Data()
  private var fragments = Data()
  private var fragmentOpcode: UInt8?
  private var upgraded = false
  private var connected = false
  private var finished = false
  private var key = ""
  private let limit = 1_048_576

  init(callback: @escaping @Sendable (Event) -> Void) { self.callback = callback }

  deinit {
    reader?.cancel()
    writer?.cancel()
    if descriptor >= 0 { Darwin.close(descriptor) }
  }

  func start(path: String) {
    queue.async { self.open(path: path) }
  }

  func send(_ data: Data) {
    queue.async {
      guard self.upgraded, !self.finished, data.count <= self.limit else { return }
      self.enqueueFrame(opcode: 1, payload: data)
    }
  }

  func stop() {
    queue.async {
      if self.upgraded { self.enqueueFrame(opcode: 8, payload: Data([3, 232])) }
      self.finish(nil)
    }
  }

  private func open(path originalPath: String) {
    guard !finished else { return }
    let path = URL(fileURLWithPath: originalPath).resolvingSymlinksInPath().path
    var entry = stat()
    guard lstat(originalPath, &entry) == 0, entry.st_uid == getuid() else {
      return finish("Сокет Codex пока недоступен")
    }
    var info = stat()
    guard lstat(path, &info) == 0 else { return finish("Сокет Codex пока недоступен") }
    guard info.st_uid == getuid(), info.st_mode & S_IFMT == S_IFSOCK,
      info.st_mode & 0o022 == 0
    else { return finish("Небезопасные права сокета Codex") }
    var parent = stat()
    guard lstat((path as NSString).deletingLastPathComponent, &parent) == 0,
      parent.st_uid == getuid(), parent.st_mode & S_IFMT == S_IFDIR,
      parent.st_mode & 0o022 == 0
    else { return finish("Небезопасный каталог сокета Codex") }
    var address = sockaddr_un()
    let bytes = Array(path.utf8CString)
    guard bytes.count <= MemoryLayout.size(ofValue: address.sun_path) else {
      return finish("Слишком длинный путь сокета Codex")
    }
    address.sun_family = sa_family_t(AF_UNIX)
    address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
    withUnsafeMutableBytes(of: &address.sun_path) { target in target.copyBytes(from: bytes.map { UInt8(bitPattern: $0) }) }
    descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
    guard descriptor >= 0 else { return finish("Не удалось открыть сокет Codex") }
    var enabled: Int32 = 1
    guard setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &enabled, socklen_t(MemoryLayout.size(ofValue: enabled))) == 0,
      fcntl(descriptor, F_SETFL, O_NONBLOCK) == 0
    else { return finish("Не удалось настроить сокет Codex") }
    let result = withUnsafePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
      }
    }
    guard result == 0 || errno == EINPROGRESS else { return finish("Не удалось подключиться к Codex") }
    key = Data((0..<16).map { _ in UInt8.random(in: 0...255) }).base64EncodedString()
    output = Data(
      ("GET / HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
        + "Sec-WebSocket-Key: \(key)\r\nSec-WebSocket-Version: 13\r\n\r\n").utf8)
    let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
    source.setEventHandler { [weak self] in self?.readAvailable() }
    source.resume()
    reader = source
    enableWriter()
    queue.asyncAfter(deadline: .now() + 10) { [weak self] in
      guard let self, !self.upgraded, !self.finished else { return }
      self.finish("Истекло время подключения к Codex")
    }
  }

  private func enableWriter() {
    guard writer == nil, !finished else { return }
    let source = DispatchSource.makeWriteSource(fileDescriptor: descriptor, queue: queue)
    source.setEventHandler { [weak self] in self?.writeAvailable() }
    source.resume()
    writer = source
  }

  private func writeAvailable() {
    guard !finished else { return }
    if !connected {
      var error: Int32 = 0
      var size = socklen_t(MemoryLayout.size(ofValue: error))
      var owner: uid_t = 0
      var group: gid_t = 0
      guard getsockopt(descriptor, SOL_SOCKET, SO_ERROR, &error, &size) == 0, error == 0,
        getpeereid(descriptor, &owner, &group) == 0, owner == getuid()
      else { return finish("Не удалось проверить соединение Codex") }
      connected = true
    }
    while !output.isEmpty {
      let count = output.withUnsafeBytes { Darwin.send(descriptor, $0.baseAddress, $0.count, 0) }
      if count > 0 {
        output.removeFirst(count)
      } else if count < 0 && errno == EINTR {
        continue
      } else if count < 0 && (errno == EAGAIN || errno == EWOULDBLOCK) {
        return
      } else {
        return finish("Ошибка записи в Codex")
      }
    }
    writer?.cancel()
    writer = nil
  }

  private func readAvailable() {
    var buffer = [UInt8](repeating: 0, count: 16_384)
    while !finished {
      let count = Darwin.recv(descriptor, &buffer, buffer.count, 0)
      if count > 0 {
        input.append(contentsOf: buffer.prefix(count))
        guard input.count <= limit + 16_384 else { return finish("Превышен размер сообщения Codex") }
        parseInput()
      } else if count == 0 {
        return finish("Соединение Codex закрыто")
      } else if errno == EINTR {
        continue
      } else if errno == EAGAIN || errno == EWOULDBLOCK {
        return
      } else {
        return finish("Ошибка чтения Codex")
      }
    }
  }

  private func parseInput() {
    if !upgraded {
      guard let end = input.range(of: Data("\r\n\r\n".utf8)) else {
        if input.count > 16_384 { finish("Некорректный ответ подключения Codex") }
        return
      }
      guard end.upperBound <= 16_384,
        let header = String(data: input[..<end.lowerBound], encoding: .utf8)
      else { return finish("Некорректный ответ подключения Codex") }
      let lines = header.components(separatedBy: "\r\n")
      var fields: [String: String] = [:]
      for line in lines.dropFirst() {
        guard let colon = line.firstIndex(of: ":") else { continue }
        fields[String(line[..<colon]).lowercased()] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
      }
      let expected = Data(Insecure.SHA1.hash(data: Data((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").utf8))).base64EncodedString()
      guard lines.first?.split(separator: " ").dropFirst().first == "101",
        fields["upgrade"]?.lowercased() == "websocket",
        fields["connection"]?.lowercased().split(separator: ",").contains(where: { $0.trimmingCharacters(in: .whitespaces) == "upgrade" })
          == true,
        fields["sec-websocket-accept"] == expected
      else { return finish("Codex отклонил подключение WebSocket") }
      input.removeSubrange(..<end.upperBound)
      upgraded = true
      callback(.opened)
    }
    while !finished, input.count >= 2 {
      guard parseFrame() else { return }
    }
  }

  private func finish(_ reason: String?) {
    guard !finished else { return }
    finished = true
    reader?.cancel()
    writer?.cancel()
    reader = nil
    writer = nil
    if descriptor >= 0 {
      Darwin.close(descriptor)
      descriptor = -1
    }
    input.removeAll()
    output.removeAll()
    fragments.removeAll()
    if let reason { callback(.closed(reason)) }
  }
}

extension CodexWebSocket {
  private func parseFrame() -> Bool {
    let bytes = Array(input.prefix(10))
    let final = bytes[0] & 0x80 != 0
    let opcode = bytes[0] & 0x0F
    var length = UInt64(bytes[1] & 0x7F)
    var header = 2
    guard bytes[0] & 0x70 == 0, bytes[1] & 0x80 == 0 else {
      finish("Некорректный кадр Codex")
      return false
    }
    if length == 126 {
      guard input.count >= 4 else { return false }
      length = UInt64(bytes[2]) << 8 | UInt64(bytes[3])
      header = 4
    } else if length == 127 {
      guard input.count >= 10 else { return false }
      length = bytes[2..<10].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
      header = 10
    }
    guard length <= limit, opcode < 8 || (final && length <= 125) else {
      finish("Превышен размер кадра Codex")
      return false
    }
    guard input.count >= header + Int(length) else { return false }
    let payload = Data(input.dropFirst(header).prefix(Int(length)))
    input.removeFirst(header + Int(length))
    return receiveFrame(opcode: opcode, final: final, payload: payload)
  }

  private func receiveFrame(opcode: UInt8, final: Bool, payload: Data) -> Bool {
    switch opcode {
    case 0:
      guard fragmentOpcode != nil else {
        finish("Неожиданный фрагмент Codex")
        return false
      }
      fragments.append(payload)
    case 1:
      guard fragmentOpcode == nil else {
        finish("Незавершённый кадр Codex")
        return false
      }
      fragments = payload
      fragmentOpcode = opcode
    default: return receiveControl(opcode: opcode, payload: payload)
    }
    guard fragments.count <= limit else {
      finish("Превышен размер сообщения Codex")
      return false
    }
    if final {
      guard String(data: fragments, encoding: .utf8) != nil else {
        finish("Некорректная кодировка Codex")
        return false
      }
      callback(.message(fragments))
      fragments = Data()
      fragmentOpcode = nil
    }
    return true
  }

  private func receiveControl(opcode: UInt8, payload: Data) -> Bool {
    switch opcode {
    case 8:
      guard payload.count != 1 else {
        finish("Некорректное закрытие Codex")
        return false
      }
      enqueueFrame(opcode: 8, payload: payload)
      finish("Соединение Codex закрыто")
      return false
    case 9:
      enqueueFrame(opcode: 10, payload: payload)
      return true
    case 10: return true
    default:
      finish("Неподдерживаемый кадр Codex")
      return false
    }
  }

  private func enqueueFrame(opcode: UInt8, payload: Data) {
    guard !finished, output.count + payload.count + 14 <= limit * 4 else {
      finish("Переполнена очередь отправки Codex")
      return
    }
    var frame = Data([0x80 | opcode])
    if payload.count < 126 {
      frame.append(0x80 | UInt8(payload.count))
    } else if payload.count <= 65_535 {
      frame.append(contentsOf: [0xFE, UInt8(payload.count >> 8), UInt8(payload.count & 255)])
    } else {
      frame.append(0xFF)
      for shift in stride(from: 56, through: 0, by: -8) { frame.append(UInt8((UInt64(payload.count) >> shift) & 255)) }
    }
    let mask = (0..<4).map { _ in UInt8.random(in: 0...255) }
    frame.append(contentsOf: mask)
    frame.append(contentsOf: payload.enumerated().map { $0.element ^ mask[$0.offset % 4] })
    output.append(frame)
    writeAvailable()
    if !output.isEmpty { enableWriter() }
  }
}
