import AppKit
import Observation
import SinteclaCore
import SwiftUI

/// Lo que decide el controlador y pinta la isla.
@MainActor @Observable
final class IslandModel {
  var form = IslandForm.notch
  /// El tamaño de la muesca de esta pantalla.
  var notch = CGSize(width: 200, height: 32)
  /// Sin muesca (tapa cerrada): isla virtual, con lo de Sintecla en una fila centrada.
  var hasNotch = true
  /// Mientras se arrastra la barra de progreso: la fracción que se enseña (de 0 a 1).
  var scrub: Double?
}

/// La isla (spec «La isla» §3): una sola forma negra que cambia de tamaño con un muelle; dentro, la música o lo de
/// Sintecla, que entran y salen con fundido. Siempre en blanco sobre negro.
struct IslandView: View {
  let model: IslandModel
  let overlay: OverlayModel
  let music: NowPlayingClient
  var onOpenApp: () -> Void
  var onCommand: (NowPlayingClient.Command) -> Void
  var onSeek: (Double) -> Void

  /// Lo que se abren las esquinas de arriba hacia los lados.
  static let flare: CGFloat = 6
  static let spring = Animation.spring(response: 0.35, dampingFraction: 0.8)
  /// Los avisos bajan con un rebote.
  static let bounce = Animation.spring(response: 0.4, dampingFraction: 0.62)

  var body: some View {
    let size = IslandLayout.size(of: model.form, notch: model.notch, hasNotch: model.hasNotch)
    island(size)
      .overlay(alignment: .topTrailing) {
        if case .activity(_, true) = model.form {
          bubble
            .offset(x: IslandLayout.bubbleDiameter(notch: model.notch) + IslandLayout.bubbleGap)
            .transition(.scale(scale: 0.3, anchor: .leading).combined(with: .opacity))
        }
      }
      .animation(isNotice ? Self.bounce : Self.spring, value: model.form)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .foregroundStyle(.white)
      .environment(\.colorScheme, .dark)
  }

  private var isNotice: Bool {
    if case .activity(.notice, _) = model.form { return true }
    return false
  }

  // MARK: La forma

  private func island(_ size: CGSize) -> some View {
    ZStack(alignment: .top) {
      IslandShape(flare: Self.flare, bottomRadius: bottomRadius).fill(.black)
      if case .activity(.processing, _) = model.form {
        Shimmer(flare: Self.flare, bottomRadius: bottomRadius)
      }
      content
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipped()
    }
    .frame(width: size.width + 2 * Self.flare, height: size.height)
    .shadow(color: .black.opacity(model.form == .expanded ? 0.35 : 0), radius: 18, y: 8)
    .opacity(model.form == .hidden ? 0 : 1)
  }

  private var bottomRadius: CGFloat {
    switch model.form {
    case .hidden, .notch: 10
    case .compact, .activity(.done, _): 13
    case .activity: 22
    case .expanded: 32
    }
  }

  // MARK: Lo de dentro

  @ViewBuilder private var content: some View {
    switch model.form {
    case .hidden, .notch:
      Color.clear
    case .compact:
      compact.transition(.opacity)
    case .expanded:
      expanded.transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
    case .activity(let activity, _):
      activityView(activity)
        .id(activity)
        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
    }
  }

  private var compact: some View {
    HStack(spacing: 0) {
      Artwork(music: music, side: 22).padding(.leading, 9)
      Spacer()
      MusicBars(playing: music.track?.isPlaying ?? false, tint: music.tint).padding(.trailing, 12)
    }
    .frame(height: model.notch.height)
  }

  @ViewBuilder private var expanded: some View {
    if let track = music.track {
      VStack(spacing: 0) {
        Color.clear.frame(height: model.notch.height)
        HStack(spacing: 12) {
          Button(action: onOpenApp) { Artwork(music: music, side: 56) }
            .buttonStyle(.plain)
            .help("Abrir la app que suena")
          VStack(alignment: .leading, spacing: 2) {
            Text(track.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
            Text(track.artist.isEmpty ? track.album : track.artist)
              .font(.system(size: 12)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
          }
          Spacer(minLength: 8)
          MusicBars(playing: track.isPlaying, tint: music.tint)
        }
        .padding(.top, 6)
        if track.duration > 0 {
          ProgressRow(track: track, model: model, onSeek: onSeek).padding(.top, 10)
        }
        HStack(spacing: 34) {
          ControlButton(symbol: "backward.fill", size: 15) { onCommand(.previous) }
          ControlButton(symbol: track.isPlaying ? "pause.fill" : "play.fill", size: 21) { onCommand(.toggle) }
          ControlButton(symbol: "forward.fill", size: 15) { onCommand(.next) }
        }
        .padding(.top, 4)
      }
      .padding(.horizontal, 22)
    }
  }

  @ViewBuilder private func activityView(_ activity: IslandActivity) -> some View {
    let phase = overlay.phase
    if !model.hasNotch {
      // Sin cámara en medio: el icono, el texto y la onda, en una fila centrada.
      HStack(spacing: 10) {
        leftWing(phase)
        if activity.isTall {
          Text(OverlayView.label(for: phase, liveText: overlay.liveText) ?? "")
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .lineLimit(1)
            .truncationMode(.head)
            .contentTransition(.opacity)
        }
        rightWing(phase)
      }
      .padding(.horizontal, 18)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if activity.isTall {
      VStack(spacing: 0) {
        HStack(spacing: 0) {
          leftWing(phase).frame(width: IslandLayout.tallWing)
          Spacer()
          rightWing(phase).frame(width: IslandLayout.tallWing)
        }
        .frame(height: model.notch.height)
        Text(OverlayView.label(for: phase, liveText: overlay.liveText) ?? "")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .lineLimit(1)
          .truncationMode(.head)
          .contentTransition(.opacity)
          .padding(.horizontal, 18)
          .frame(height: IslandLayout.tallDrop - 6)
      }
    } else {
      HStack {
        leftWing(phase).frame(width: IslandLayout.wing)
        Spacer()
      }
      .frame(height: model.notch.height)
    }
  }

  @ViewBuilder private func leftWing(_ phase: OverlayModel.Phase) -> some View {
    if case .processing = phase {
      Spinner()
    } else {
      Image(systemName: OverlayView.symbol(for: phase))
        .font(.system(size: 15, weight: .semibold))
        .contentTransition(.symbolEffect(.replace))
    }
  }

  @ViewBuilder private func rightWing(_ phase: OverlayModel.Phase) -> some View {
    switch phase {
    case .listening(.meeting):
      if let startedAt = overlay.startedAt {
        TimelineView(.periodic(from: startedAt, by: 1)) { context in
          Text(OverlayView.clock(context.date.timeIntervalSince(startedAt)))
            .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
        }
      }
    case .listening(.notes):
      HStack(spacing: 6) {
        if let startedAt = overlay.startedAt {
          TimelineView(.periodic(from: startedAt, by: 1)) { context in
            Text(OverlayView.clock(context.date.timeIntervalSince(startedAt)))
              .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
          }
        }
        LevelBars(level: overlay.level).scaleEffect(0.8)
      }
    case .listening:
      LevelBars(level: overlay.level).scaleEffect(0.8)
    default:
      EmptyView()
    }
  }

  // MARK: La burbuja

  private var bubble: some View {
    let side = IslandLayout.bubbleDiameter(notch: model.notch)
    return Circle().fill(.black)
      .frame(width: side, height: side)
      .overlay {
        Artwork(music: music, side: side - 10).clipShape(.circle)
      }
      .overlay(alignment: .bottomTrailing) {
        if music.track?.isPlaying == false {
          Image(systemName: "pause.fill").font(.system(size: 7, weight: .bold))
            .padding(3).background(.black, in: .circle)
        }
      }
  }
}

/// La carátula, o el icono de la app que suena si no hay.
private struct Artwork: View {
  let music: NowPlayingClient
  let side: CGFloat

  var body: some View {
    Group {
      if let artwork = music.artwork {
        Image(nsImage: artwork).resizable().aspectRatio(contentMode: .fill)
      } else if let pid = music.track?.pid, let icon = NSRunningApplication(processIdentifier: pid)?.icon {
        Image(nsImage: icon).resizable()
      } else {
        Image(systemName: "music.note").resizable().scaledToFit().padding(side * 0.2)
      }
    }
    .frame(width: side, height: side)
    .clipShape(.rect(cornerRadius: side * 0.24))
  }
}

/// La onda de la música: 4 barras animadas del color de la carátula, quietas en pausa (spec «La isla» §3.2). No sigue
/// el sonido real.
struct MusicBars: View {
  let playing: Bool
  let tint: ArtworkTint
  private static let speeds: [Double] = [5.1, 7.3, 6.2, 8.9]
  private static let phases: [Double] = [0, 1.3, 2.1, 0.7]

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !playing)) { context in
      let time = context.date.timeIntervalSinceReferenceDate
      HStack(spacing: 2) {
        ForEach(0..<4, id: \.self) { index in
          Capsule()
            .fill(Color(red: tint.red, green: tint.green, blue: tint.blue))
            .frame(width: 3, height: playing ? Self.height(index, time) : 3)
        }
      }
    }
    .frame(height: 14)
    .animation(.easeInOut(duration: 0.25), value: playing)
  }

  private static func height(_ index: Int, _ time: Double) -> CGFloat {
    let wave = (sin(time * speeds[index] + phases[index]) + 1) / 2
    let swell = 0.6 + 0.4 * (sin(time * 1.7 + Double(index)) + 1) / 2
    return 4 + 10 * CGFloat(wave * swell)
  }
}

/// La barra de progreso, que se puede arrastrar, y los tiempos.
private struct ProgressRow: View {
  let track: NowPlaying
  let model: IslandModel
  var onSeek: (Double) -> Void

  var body: some View {
    TimelineView(.periodic(from: .now, by: 0.5)) { context in
      let fraction = model.scrub ?? track.progress(at: context.date)
      let position = fraction * track.duration
      VStack(spacing: 4) {
        GeometryReader { geometry in
          Capsule().fill(.white.opacity(0.2))
            .overlay(alignment: .leading) {
              Capsule().fill(.white).frame(width: geometry.size.width * fraction)
            }
            .frame(height: model.scrub == nil ? 4 : 6)
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0)
              .onChanged { model.scrub = min(1, max(0, $0.location.x / geometry.size.width)) }
              .onEnded { _ in if let scrub = model.scrub { onSeek(scrub) } })
        }
        .frame(height: 10)
        .animation(.easeOut(duration: 0.15), value: model.scrub == nil)
        HStack {
          Text(NowPlaying.clock(position))
          Spacer()
          Text("-" + NowPlaying.clock(track.duration - position))
        }
        .font(.system(size: 10, weight: .medium).monospacedDigit())
        .foregroundStyle(.white.opacity(0.55))
      }
    }
  }
}

/// Un control de la música: se ilumina con el ratón encima.
private struct ControlButton: View {
  let symbol: String
  let size: CGFloat
  let action: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: size, weight: .semibold))
        .contentTransition(.symbolEffect(.replace))
        .frame(width: 30, height: 26)
        .opacity(hovering ? 1 : 0.85)
        .scaleEffect(hovering ? 1.1 : 1)
        .animation(.easeOut(duration: 0.12), value: hovering)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }
}

/// Procesando: un arco que gira, dibujado a mano para que vaya a juego con el brillo del borde.
private struct Spinner: View {
  var body: some View {
    TimelineView(.animation) { context in
      Circle()
        .trim(from: 0.15, to: 1)
        .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        .rotationEffect(.degrees(context.date.timeIntervalSinceReferenceDate * 360))
    }
    .frame(width: 14, height: 14)
  }
}

/// Procesando: un brillo que recorre el borde de la isla.
private struct Shimmer: View {
  let flare: CGFloat
  let bottomRadius: CGFloat

  var body: some View {
    TimelineView(.animation) { context in
      let angle = context.date.timeIntervalSinceReferenceDate * 220
      IslandShape(flare: flare, bottomRadius: bottomRadius)
        .stroke(AngularGradient(colors: [.clear, .white.opacity(0.85), .clear, .clear], center: .center,
                                angle: .degrees(angle)), lineWidth: 1.5)
    }
  }
}
