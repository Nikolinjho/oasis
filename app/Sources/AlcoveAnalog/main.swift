import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)

// pkill и kill по умолчанию шлют SIGTERM: без обработчика процесс умирает сразу,
// applicationWillTerminate не вызывается, и адаптер остаётся сиротой. Переводим сигнал в штатный выход
let terminationSignals: [DispatchSourceSignal] = [SIGTERM, SIGINT, SIGHUP].map { number in
    signal(number, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
    source.setEventHandler {
        MainActor.assumeIsolated { NSApp.terminate(nil) }
    }
    source.resume()
    return source
}

app.run()
