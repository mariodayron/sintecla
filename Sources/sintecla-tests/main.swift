import Foundation
import Testing

// Lanza todos los @Test enlazados (SinteclaCoreTests). Admite `--filter <nombre>`.
let code: CInt = await Testing.__swiftPMEntryPoint()
exit(code)
