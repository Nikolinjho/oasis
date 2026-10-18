import Darwin
import Foundation

extension ClaudeHooksInstaller {
  func withConnectionLock(_ action: () throws -> Void) throws {
    try prepareSupportDirectory()
    try validateSupportDirectory()
    let lockURL = directory.appendingPathComponent("hooks.lock")
    let descriptor = open(lockURL.path, O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, 0o600)
    guard descriptor >= 0 else { throw posixFailure() }
    defer { close(descriptor) }
    var info = stat()
    guard fstat(descriptor, &info) == 0, info.st_uid == getuid(), info.st_mode & S_IFMT == S_IFREG,
      fchmod(descriptor, 0o600) == 0
    else { throw Failure(message: "Небезопасный файл блокировки Claude") }
    guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
      throw Failure(message: "Подключение Claude меняется в другом окне Oasis. Повтори действие")
    }
    defer { flock(descriptor, LOCK_UN) }
    try action()
  }

  func prepareSupportDirectory() throws {
    var components: [URL] = []
    var component = directory.standardizedFileURL
    while component.path != "/" {
      components.append(component)
      component.deleteLastPathComponent()
    }
    for component in components.reversed() {
      var info = stat()
      if lstat(component.path, &info) != 0 {
        guard errno == ENOENT else { throw posixFailure() }
        try FileManager.default.createDirectory(at: component, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        guard lstat(component.path, &info) == 0 else { throw posixFailure() }
      }
      guard info.st_mode & S_IFMT == S_IFDIR else {
        throw Failure(message: "Каталог подключения Claude содержит символическую ссылку")
      }
    }
  }

  func validateSupportDirectory() throws {
    var component = directory.standardizedFileURL
    while component.path != "/" {
      var info = stat()
      guard lstat(component.path, &info) == 0, info.st_mode & S_IFMT == S_IFDIR else {
        throw Failure(message: "Каталог подключения Claude отсутствует или содержит символическую ссылку")
      }
      if component == directory {
        guard info.st_uid == getuid(), info.st_mode & 0o777 == 0o700 else {
          throw Failure(message: "Каталог подключения Claude должен принадлежать пользователю и иметь права 0700")
        }
      }
      component.deleteLastPathComponent()
    }
  }

  func read(_ url: URL) throws -> Data? {
    let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
    if descriptor < 0 {
      if errno == ENOENT { return nil }
      throw posixFailure()
    }
    let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    defer { try? handle.close() }
    var info = stat()
    guard fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_uid == getuid() else {
      throw Failure(message: "Небезопасный файл подключения Claude")
    }
    return try handle.readToEnd() ?? Data()
  }

  func object(_ data: Data?) throws -> [String: Any] {
    guard let data else { return [:] }
    guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw Failure(message: "Настройки Claude должны содержать JSON-объект")
    }
    return value
  }

  func encode(_ value: [String: Any]) throws -> Data {
    try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
  }

  func atomicWrite(_ data: Data, to url: URL, permissions: mode_t, beforeRename: () throws -> Void = {}) throws {
    let temporary = url.deletingLastPathComponent().appendingPathComponent(".oasis-\(UUID().uuidString).tmp")
    let descriptor = open(temporary.path, O_CREAT | O_EXCL | O_WRONLY | O_NOFOLLOW | O_CLOEXEC, permissions)
    guard descriptor >= 0 else { throw posixFailure() }
    let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    defer {
      try? handle.close()
      try? FileManager.default.removeItem(at: temporary)
    }
    guard fchmod(descriptor, permissions) == 0 else { throw posixFailure() }
    try handle.write(contentsOf: data)
    try handle.synchronize()
    try beforeRename()
    guard rename(temporary.path, url.path) == 0 else { throw posixFailure() }
  }

  func posixFailure() -> NSError {
    NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
  }
}
