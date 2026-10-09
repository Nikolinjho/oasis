import Foundation

public struct YandexListener: Sendable, Equatable {
  public var pid: Int32
  public var address: String
  public init(pid: Int32, address: String) {
    self.pid = pid
    self.address = address
  }
}

enum YandexEndpoint {
  static func isOwned(_ listeners: [YandexListener], pid: Int32, port: Int) -> Bool {
    !listeners.isEmpty && listeners.allSatisfy { $0.pid == pid && $0.address == "127.0.0.1:\(port)" }
  }
  static func websocket(from data: Data, port: Int) throws -> URL {
    struct Target: Decodable {
      let type: String
      let url: String
      let webSocketDebuggerUrl: String?
    }
    let targets = try JSONDecoder().decode([Target].self, from: data)
    for target in targets where target.type == "page" {
      guard let page = URL(string: target.url), page.scheme == "music-application", page.host == "desktop", page.user == nil,
        page.password == nil,
        let raw = target.webSocketDebuggerUrl, let websocket = URL(string: raw),
        websocket.scheme == "ws", websocket.host == "127.0.0.1", websocket.port == port,
        websocket.user == nil, websocket.password == nil, websocket.query == nil, websocket.fragment == nil,
        websocket.path.hasPrefix("/devtools/page/")
      else { continue }
      return websocket
    }
    throw YandexClientError.notReady
  }
}

public protocol YandexHTTP: Sendable {
  func targets(port: Int) async throws -> Data
}

final class YandexNoRedirects: NSObject, URLSessionTaskDelegate, Sendable {
  func urlSession(
    _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
  ) { completionHandler(nil) }
}

public actor YandexLoopbackHTTP: YandexHTTP {
  private let session: URLSession
  public init() {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.connectionProxyDictionary = [:]
    configuration.httpCookieStorage = nil
    configuration.timeoutIntervalForRequest = 2
    session = URLSession(configuration: configuration, delegate: YandexNoRedirects(), delegateQueue: nil)
  }
  public func targets(port: Int) async throws -> Data {
    guard (1...65535).contains(port), let url = URL(string: "http://127.0.0.1:\(port)/json/list") else {
      throw YandexClientError.unsafeEndpoint
    }
    let (data, response) = try await session.data(from: url)
    guard let response = response as? HTTPURLResponse, response.statusCode == 200,
      response.url == url, data.count <= 2_000_000
    else { throw YandexClientError.unsafeEndpoint }
    return data
  }
}
