import Testing
@testable import SinteclaCore

@Suite struct RulesCleanerTests {
  let cleaner = RulesCleaner()

  @Test(arguments: [
    // Frases probadas con el modelo de Apple durante el diseño
    ("eh bueno pues mañana a las cinco no perdón a las seis tenemos la reunión con con Brisenta",
     "mañana a las seis tenemos la reunión con Brisenta"),
    ("escríbele a Juan que el pedido llega el jueves mejor dicho el viernes por la mañana",
     "escríbele a Juan que el pedido llega el viernes por la mañana"),
    ("el informe lo tengo yo no espera lo tiene Ana", "el informe lo tiene Ana"),
    ("Eh, bueno, mañana a las cinco, no, perdón, a las seis tenemos la reunión.",
     "mañana a las seis tenemos la reunión."),
    ("compra manzanas no perdón peras", "compra peras"),
    ("manda el correo a las nueve no perdón a las diez y media", "manda el correo a las diez y media"),
    ("quedamos en la oficina mejor dicho en el almacén", "quedamos en el almacén"),
  ])
  func appliesCorrections(input: String, expected: String) {
    #expect(cleaner.clean(input) == expected)
  }

  @Test(arguments: [
    "él no espera nada de esta reunión",
    "ahora quiero decir algo importante",
    "llego tarde perdón por el retraso",
    "Voy a casa y el tren no espera a nadie",
    "el pedido tiene que salir hoy sí o sí",
  ])
  func leavesNormalSentencesAlone(input: String) {
    #expect(cleaner.clean(input) == input)
  }

  @Test func removesFillersAndRepeats() {
    #expect(cleaner.clean("no no no eso no es así") == "no eso no es así")
    #expect(cleaner.clean("el precio, el precio es alto") == "el precio es alto")
    #expect(cleaner.clean("en plan no sé si llegaremos a tiempo") == "no sé si llegaremos a tiempo")
    #expect(cleaner.clean("mmm vale vale lo miro esta tarde") == "lo miro esta tarde")
  }

  @Test func neverEmptiesAShortReply() {
    #expect(cleaner.clean("vale") == "vale")
    #expect(cleaner.clean("eh vale") == "vale")
    #expect(cleaner.clean("eh em") == "")
  }

  @Test func keepsQuestionMarksWhenRemovingFillers() {
    #expect(cleaner.clean("¿eh, qué hora es?") == "¿qué hora es?")
    #expect(cleaner.clean("vale, ¿vienes, eh?") == "¿vienes?")
  }
}
