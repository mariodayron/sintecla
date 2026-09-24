import AppKit

// Modos de prueba (ver DebugCommands): imprimen el resultado y salen.
if let command = DebugCommands.command(for: CommandLine.arguments) {
  Task { @MainActor in
    print(await command())
    exit(0)
  }
  RunLoop.main.run()
}

// El código de nivel superior no es @MainActor en modo Swift 5: se declara aquí.
MainActor.assumeIsolated {
  let app = NSApplication.shared
  let delegate = AppDelegate()  // app.delegate es weak: vive mientras run() no vuelve
  app.delegate = delegate
  app.setActivationPolicy(.accessory)  // sin icono en el Dock, solo barra de menú
  app.run()
}
