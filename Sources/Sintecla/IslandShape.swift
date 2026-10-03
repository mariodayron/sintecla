import SwiftUI

/// La forma de la isla (spec «La isla» §3.1): como la muesca, pegada al borde de arriba, con las esquinas de arriba
/// abiertas hacia fuera (`flare`) y las de abajo redondeadas (`bottomRadius`). El cuerpo ocupa todo el ancho menos las
/// dos curvas de arriba. Los dos radios se animan con el muelle, igual que el tamaño.
struct IslandShape: Shape {
  var flare: CGFloat
  var bottomRadius: CGFloat

  var animatableData: AnimatablePair<CGFloat, CGFloat> {
    get { AnimatablePair(flare, bottomRadius) }
    set {
      flare = newValue.first
      bottomRadius = newValue.second
    }
  }

  func path(in rect: CGRect) -> Path {
    let flare = min(flare, rect.width / 4, rect.height / 2)
    let radius = min(bottomRadius, (rect.width - 2 * flare) / 2, rect.height - flare)
    let left = rect.minX + flare, right = rect.maxX - flare
    var path = Path()
    path.move(to: CGPoint(x: rect.minX, y: rect.minY))
    path.addQuadCurve(to: CGPoint(x: left, y: rect.minY + flare), control: CGPoint(x: left, y: rect.minY))
    path.addArc(tangent1End: CGPoint(x: left, y: rect.maxY), tangent2End: CGPoint(x: right, y: rect.maxY), radius: radius)
    path.addArc(tangent1End: CGPoint(x: right, y: rect.maxY), tangent2End: CGPoint(x: right, y: rect.minY), radius: radius)
    path.addLine(to: CGPoint(x: right, y: rect.minY + flare))
    path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: right, y: rect.minY))
    path.closeSubpath()
    return path
  }
}
