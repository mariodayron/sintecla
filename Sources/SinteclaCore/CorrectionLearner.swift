import Foundation

/// Palabras que el usuario corrigió después de pegar: lo dictado → lo que escribió en su lugar.
public struct Correction: Equatable, Sendable {
  public var dictated: String
  public var corrected: String

  public init(dictated: String, corrected: String) {
    self.dictated = dictated
    self.corrected = corrected
  }
}

/// Compara lo que pegó Sintecla con cómo quedó el campo y devuelve las palabras corregidas.
/// Las reescrituras, los cambios de mayúsculas o tildes y las sustituciones que no se parecen no cuentan.
public enum CorrectionLearner {
  /// Palabras por lado en una corrección (1 a 3).
  public static let maxBlock = 3
  /// Parte de lo pegado que debe seguir en el campo para compararlo.
  public static let minFound = 2.0 / 3.0
  /// Si cambia más de esta parte de lo pegado, es una reescritura.
  public static let maxChanged = 1.0 / 3.0
  /// Distancia máxima entre lo dictado y lo corregido, simplificados al oído.
  public static let maxSoundDistance = 0.5

  public static func corrections(pasted: String, field: String) -> [Correction] {
    let p = words(pasted), f = words(field)
    guard let alignment = align(p, f), isFound(alignment, count: p.count),
          Double(p.count - alignment.matches) <= Double(p.count) * maxChanged else { return [] }
    return alignment.blocks.compactMap { block in
      let dictated = block.pasted.map { p[$0].text }, corrected = block.field.map { f[$0].text }
      return accepts(dictated, corrected)
        ? Correction(dictated: dictated.joined(separator: " "), corrected: corrected.joined(separator: " ")) : nil
    }
  }

  /// ¿Sigue lo pegado en el campo (al menos 2/3 de sus palabras, en orden)?
  public static func contains(_ pasted: String, in field: String) -> Bool {
    let p = words(pasted)
    guard let alignment = align(p, words(field)) else { return false }
    return isFound(alignment, count: p.count)
  }

  /// Forma simplificada al oído: sin tildes ni mayúsculas; v → b, z → s, c ante e-i → s, ll → y, h muda,
  /// qu → k, g ante e-i → j.
  public static func soundKey(_ text: String) -> String {
    var s = TextMetrics.fold(text).filter { $0.isLetter || $0.isNumber }
    s = s.replacingOccurrences(of: "ch", with: "ç")
      .replacingOccurrences(of: "h", with: "")
      .replacingOccurrences(of: "qu", with: "k")
      .replacingOccurrences(of: "ll", with: "y")
      .replacingOccurrences(of: "v", with: "b")
      .replacingOccurrences(of: "z", with: "s")
      .replacingOccurrences(of: "c(?=[ei])", with: "s", options: .regularExpression)
      .replacingOccurrences(of: "g(?=[ei])", with: "j", options: .regularExpression)
      .replacingOccurrences(of: "ç", with: "ch")
    return s
  }

  // MARK: - Alineado

  struct Word {
    let text: String
    let key: String
  }

  struct Block {
    var pasted: [Int] = []
    var field: [Int] = []
  }

  struct Alignment {
    var matches = 0
    var blocks: [Block] = []
  }

  static func words(_ text: String) -> [Word] {
    let ns = text as NSString
    return PersonalDictionary.wordRegex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map {
      let word = ns.substring(with: $0.range)
      return Word(text: word, key: TextMetrics.fold(word))
    }
  }

  static func isFound(_ alignment: Alignment, count: Int) -> Bool {
    count > 0 && Double(alignment.matches) >= Double(count) * minFound
  }

  static func accepts(_ dictated: [String], _ corrected: [String]) -> Bool {
    guard (1...maxBlock).contains(dictated.count), (1...maxBlock).contains(corrected.count),
          dictated.map(TextMetrics.fold) != corrected.map(TextMetrics.fold),
          corrected.joined().filter(\.isLetter).count >= 3,
          dictated.joined().contains(where: \.isNumber) == corrected.joined().contains(where: \.isNumber) else { return false }
    return PersonalDictionary.normalizedDistance(soundKey(dictated.joined()), soundKey(corrected.joined())) <= maxSoundDistance
  }

  /// Alineado de lo pegado con un tramo del campo (lo que hay antes y después en el campo no cuesta).
  /// Sustituir cuesta un poco menos que borrar + insertar para que una palabra cambiada salga como sustitución.
  static func align(_ p: [Word], _ f: [Word]) -> Alignment? {
    let n = p.count, m = f.count
    guard n > 0, m > 0 else { return nil }
    // 0 = inicio, 1 = diagonal, 2 = palabra pegada borrada, 3 = palabra nueva insertada.
    var from = [UInt8](repeating: 0, count: (n + 1) * (m + 1))
    var previous = [Double](repeating: 0, count: m + 1)
    var current = previous
    for i in 1...n {
      current[0] = Double(i)
      from[i * (m + 1)] = 2
      for j in 1...m {
        let diagonal = previous[j - 1] + (p[i - 1].key == f[j - 1].key ? 0 : 0.9)
        let up = previous[j] + 1
        let left = current[j - 1] + 1
        if diagonal <= up && diagonal <= left {
          current[j] = diagonal
          from[i * (m + 1) + j] = 1
        } else if up <= left {
          current[j] = up
          from[i * (m + 1) + j] = 2
        } else {
          current[j] = left
          from[i * (m + 1) + j] = 3
        }
      }
      swap(&previous, &current)
    }
    var end = 0
    for j in 0...m where previous[j] < previous[end] { end = j }

    var result = Alignment()
    var block = Block()
    func close() {
      if !block.pasted.isEmpty || !block.field.isEmpty { result.blocks.append(block) }
      block = Block()
    }
    var i = n, j = end
    while i > 0 {
      switch from[i * (m + 1) + j] {
      case 1:
        if p[i - 1].key == f[j - 1].key {
          close()
          result.matches += 1
        } else {
          block.pasted.insert(i - 1, at: 0)
          block.field.insert(j - 1, at: 0)
        }
        i -= 1
        j -= 1
      case 2:
        block.pasted.insert(i - 1, at: 0)
        i -= 1
      default:
        block.field.insert(j - 1, at: 0)
        j -= 1
      }
    }
    close()
    result.blocks.reverse()
    return result
  }
}
