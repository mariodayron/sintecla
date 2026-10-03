// Generado a partir de MacRemote (mac_remote.py), traducido, con el punto de conexión y la llave en cada petición.
// No lleva barras invertidas.

/// La página del móvil del módulo Mando: trackpad, música, volumen, teclado y atajos. Habla con Sintecla por
/// WebSocket en `/ws` y, mientras conecta, con `POST /action`.
enum RemoteWebPage {
  static let html = #"""
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
<title>Sintecla · Mando</title>
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-title" content="Mando">
<meta name="theme-color" content="#000000">
<link rel="manifest" href="/manifest.json">
<link rel="apple-touch-icon" href="/icon.png">
<style>
  :root {
    --bg: #000000;
    --card: #1C1C1E;
    --card-active: #2C2C2E;
    --text: #FFFFFF;
    --text-muted: #8E8E93;
    --accent: #0A84FF;
    --danger: #FF453A;
    --radius: 20px;
  }
  @media (prefers-color-scheme: light) {
    :root {
      --bg: #F2F2F7;
      --card: #FFFFFF;
      --card-active: #E5E5EA;
      --text: #000000;
      --text-muted: #8E8E93;
      --accent: #007AFF;
    }
  }
  * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; user-select: none; }
  body {
    margin: 0; padding: env(safe-area-inset-top) 16px env(safe-area-inset-bottom) 16px;
    background: var(--bg); color: var(--text);
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    height: 100dvh; display: flex; flex-direction: column; overflow: hidden;
  }

  /* Header */
  .header { display: flex; justify-content: space-between; align-items: center; padding: 12px 8px; }
  .header-title { font-size: 17px; font-weight: 600; letter-spacing: -0.4px; display: flex; align-items: center; gap: 8px; }
  .link-dot { width: 8px; height: 8px; border-radius: 4px; background: var(--danger); transition: background .3s; }
  .link-dot.on { background: #30D158; }
  .battery { font-size: 13px; font-weight: 500; color: var(--text-muted); display: flex; align-items: center; gap: 4px; }

  /* Trackpad */
  .trackpad-container {
    flex: 3; display: flex; position: relative;
    background: var(--card); border-radius: 28px;
    box-shadow: 0 4px 24px rgba(0,0,0,0.04);
    margin-bottom: 16px; overflow: hidden;
    transition: transform 0.1s, background 0.2s;
  }
  .trackpad-container.active { background: var(--card-active); transform: scale(0.98); }
  #pad { flex: 1; position: relative; }
  #fast-scroll {
    width: 44px; border-left: 1px solid rgba(128,128,128,0.1);
    display: flex; align-items: center; justify-content: center;
  }
  .scroll-indicator { width: 4px; height: 40px; background: var(--text-muted); border-radius: 2px; opacity: 0.3; }

  /* Control Modules */
  .controls-grid {
    display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; margin-bottom: 8px;
  }
  
  .module {
    background: var(--card); border-radius: var(--radius);
    display: flex; align-items: center; justify-content: center;
    box-shadow: 0 4px 12px rgba(0,0,0,0.03); cursor: pointer;
    transition: transform 0.1s;
  }
  .module:active { background: var(--card-active); transform: scale(0.95); }
  
  /* Input wrapper */
  .input-wrapper { display: flex; gap: 10px; grid-column: span 4; margin-bottom: 10px; }
  #keyboard-input { flex: 1; height: 44px; background: var(--card); border: none; border-radius: var(--radius); padding: 0 14px; color: var(--text); font-size: 16px; outline: none; box-shadow: 0 4px 12px rgba(0,0,0,0.03); }
  #btn-send { width: 44px; height: 44px; background: var(--accent); border: none; border-radius: var(--radius); color: #fff; display: flex; align-items: center; justify-content: center; box-shadow: 0 4px 12px rgba(0,122,255,0.3); }
  #btn-send:active { transform: scale(0.92); opacity: 0.8; }

  /* Specific Modules */
  .mod-vol { grid-column: span 4; padding: 0 16px; height: 44px; display: flex; gap: 12px; }
  input[type=range] {
    flex: 1; height: 6px; -webkit-appearance: none; background: rgba(128,128,128,0.2); border-radius: 4px; outline: none;
  }
  input[type=range]::-webkit-slider-thumb {
    -webkit-appearance: none; width: 24px; height: 24px; background: #fff;
    border-radius: 50%; box-shadow: 0 2px 8px rgba(0,0,0,0.2); cursor: pointer;
  }

  .mod-media { grid-column: span 4; display: grid; grid-template-columns: 1fr 1fr 1fr; height: 50px; background: var(--card); border-radius: var(--radius); overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.03); }
  .media-btn { display: flex; align-items: center; justify-content: center; color: var(--text); }
  .media-btn:active { background: var(--card-active); }

  .mod-btn { height: 50px; flex-direction: column; gap: 3px; font-size: 10px; font-weight: 500; color: var(--text-muted); }
  .mod-btn svg { width: 18px; height: 18px; fill: var(--text); }

  .mod-clicks { grid-column: span 4; display: grid; grid-template-columns: 1fr 1fr; gap: 12px; background: transparent; }
  .click-btn { height: 46px; background: var(--card); border-radius: var(--radius); display: flex; align-items: center; justify-content: center; font-size: 14px; font-weight: 600; box-shadow: 0 4px 12px rgba(0,0,0,0.03); }
  .click-btn:active { background: var(--card-active); transform: scale(0.97); }

  /* iOS-style overlay menu */
  #menu-overlay {
    position: fixed; inset: 0;
    background: #1C1C1E;
    background-image: radial-gradient(ellipse at top, rgba(80,80,90,0.35), transparent 60%);
    z-index: 100;
    display: flex; flex-direction: column;
    padding-top: env(safe-area-inset-top);
    transform: translateY(100%);
    transition: transform 0.5s cubic-bezier(0.32, 0.72, 0, 1);
  }
  #menu-overlay.open { transform: translateY(0); }

  .menu-handle {
    width: 36px; height: 5px;
    background: rgba(235,235,245,0.3);
    border-radius: 99px;
    margin: 8px auto 0;
    flex-shrink: 0;
  }
  .menu-titlebar {
    display: flex; align-items: center; justify-content: space-between;
    padding: 14px 20px 8px;
  }
  .menu-title { font-size: 28px; font-weight: 700; letter-spacing: 0.36px; color: #fff; }
  .menu-done {
    font-size: 17px; font-weight: 600; color: #0A84FF;
    background: none; border: none; padding: 4px 8px; cursor: pointer;
    -webkit-tap-highlight-color: transparent;
  }
  .menu-done:active { opacity: 0.5; }

  .menu-scroll {
    flex: 1; overflow-y: auto;
    padding: 0 16px env(safe-area-inset-bottom);
    -webkit-overflow-scrolling: touch;
  }

  .section-header {
    font-size: 13px; font-weight: 400;
    color: rgba(235,235,245,0.7);
    text-transform: uppercase;
    letter-spacing: -0.08px;
    padding: 26px 16px 6px;
  }
  .section-card {
    background: rgba(255,255,255,0.07);
    border-radius: 14px; overflow: hidden;
  }

  .cell {
    display: flex; align-items: center; gap: 12px;
    padding: 10px 16px; min-height: 44px;
    position: relative; cursor: pointer;
  }
  .cell + .cell::before {
    content: ''; position: absolute; top: 0; left: 56px; right: 0;
    height: 0.5px; background: rgba(255,255,255,0.13);
  }
  .cell:active { background: rgba(255,255,255,0.06); }

  .cell-icon {
    width: 30px; height: 30px; border-radius: 7px;
    display: flex; align-items: center; justify-content: center;
    flex-shrink: 0;
  }
  .cell-icon svg { width: 18px; height: 18px; fill: #fff; }
  .cell-label { flex: 1; font-size: 17px; color: #fff; letter-spacing: -0.4px; }
  .cell-value { font-size: 17px; color: rgba(235,235,245,0.6); letter-spacing: -0.4px; }
  .cell-chevron { color: rgba(235,235,245,0.3); font-size: 18px; font-weight: 300; margin-left: -4px; }
  .cell-danger { color: var(--danger); font-weight: 500; }

  .cell-vertical { flex-direction: column; align-items: stretch; gap: 10px; padding: 14px 16px; }
  .cell-row { display: flex; justify-content: space-between; align-items: center; }

  .slim-slider {
    width: 100%; height: 4px;
    -webkit-appearance: none; appearance: none;
    background: rgba(255,255,255,0.22);
    border-radius: 4px; outline: none;
  }
  .slim-slider::-webkit-slider-thumb {
    -webkit-appearance: none; width: 26px; height: 26px;
    background: #fff; border-radius: 50%;
    box-shadow: 0 3px 8px rgba(0,0,0,0.2), 0 0 0 0.5px rgba(0,0,0,0.04);
  }

  .stepper {
    display: flex; align-items: center;
    background: rgba(255,255,255,0.12);
    border-radius: 8px; overflow: hidden; height: 32px;
  }
  .stepper-btn {
    width: 44px; height: 32px;
    background: none; border: none;
    color: #fff; font-size: 20px; font-weight: 400;
    display: flex; align-items: center; justify-content: center; cursor: pointer;
  }
  .stepper-btn:active { background: rgba(255,255,255,0.1); }
  .stepper-sep { width: 0.5px; height: 16px; background: rgba(255,255,255,0.18); }

  .streaming-grid {
    display: grid; grid-template-columns: 1fr 1fr 1fr;
    gap: 8px; padding: 10px;
  }
  .streaming-btn {
    height: 52px; border: none; border-radius: 10px;
    color: #fff; font-size: 13px; font-weight: 600;
    letter-spacing: -0.2px; cursor: pointer;
    box-shadow: 0 1px 3px rgba(0,0,0,0.15);
    transition: opacity 0.1s, transform 0.1s;
  }
  .streaming-btn:active { opacity: 0.7; transform: scale(0.96); }

  .segmented {
    display: grid; grid-template-columns: repeat(4, 1fr);
    gap: 3px; padding: 3px;
    background: rgba(0,0,0,0.3);
    border-radius: 9px; margin: 8px;
  }
  .seg-btn {
    height: 32px; background: transparent;
    border: none; border-radius: 7px;
    color: #fff; font-size: 13px; font-weight: 500;
    cursor: pointer; transition: background 0.15s;
  }
  .seg-btn.active {
    background: rgba(120,120,130,0.85);
    box-shadow: 0 3px 8px rgba(0,0,0,0.25), 0 0 0 0.5px rgba(255,255,255,0.06);
  }
  .seg-btn:active:not(.active) { background: rgba(255,255,255,0.08); }

  svg { width: 24px; height: 24px; fill: currentColor; }

  /* ── Notch Now Playing ── */
  #notch {
    position: fixed; top: 8px; left: 50%; transform: translateX(-50%);
    z-index: 300;
    background: #000; border-radius: 999px;
    overflow: hidden;
    cursor: pointer;
    box-shadow: 0 4px 24px rgba(0,0,0,0.5);
    transition: width 0.45s cubic-bezier(0.34,1.56,0.64,1),
                height 0.45s cubic-bezier(0.34,1.56,0.64,1),
                border-radius 0.45s ease,
                opacity 0.3s ease;
    width: 120px; height: 34px;
    opacity: 0; pointer-events: none;
  }
  #notch.visible { opacity: 1; pointer-events: auto; }
  #notch.expanded { width: min(340px, 90vw); height: 80px; border-radius: 26px; }

  #notch-collapsed {
    position: absolute; inset: 0;
    display: flex; align-items: center; justify-content: center; gap: 8px;
    transition: opacity 0.2s;
  }
  #notch.expanded #notch-collapsed { opacity: 0; pointer-events: none; }

  .notch-bars {
    display: flex; align-items: flex-end; gap: 2px; height: 14px;
  }
  .notch-bars span {
    display: block; width: 3px; background: #1DB954; border-radius: 2px;
    animation: bar-bounce 0.8s ease-in-out infinite alternate;
  }
  .notch-bars span:nth-child(1) { height: 6px;  animation-delay: 0s; }
  .notch-bars span:nth-child(2) { height: 11px; animation-delay: 0.15s; }
  .notch-bars span:nth-child(3) { height: 8px;  animation-delay: 0.3s; }
  .notch-bars span:nth-child(4) { height: 14px; animation-delay: 0.1s; }
  @keyframes bar-bounce {
    from { transform: scaleY(0.4); }
    to   { transform: scaleY(1); }
  }

  #notch-title-mini {
    font-size: 12px; font-weight: 600; color: #fff;
    white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
    max-width: 70px;
  }

  #notch-expanded {
    position: absolute; inset: 0;
    display: flex; align-items: center; gap: 12px; padding: 0 14px;
    opacity: 0; transition: opacity 0.2s 0.15s;
  }
  #notch.expanded #notch-expanded { opacity: 1; }

  #notch-art {
    width: 52px; height: 52px; border-radius: 10px; flex-shrink: 0;
    background: linear-gradient(135deg, #1DB954, #191414);
    object-fit: cover; display: flex; align-items: center; justify-content: center;
  }
  #notch-art img { width: 100%; height: 100%; border-radius: 10px; object-fit: cover; }
  #notch-art svg { width: 24px; height: 24px; fill: rgba(255,255,255,0.4); }

  #notch-info { flex: 1; min-width: 0; }
  #notch-song {
    font-size: 13px; font-weight: 700; color: #fff;
    white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
  }
  #notch-artist {
    font-size: 11px; color: rgba(255,255,255,0.55); margin-top: 2px;
    white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
  }

  .notch-bars-big {
    display: flex; align-items: flex-end; gap: 3px; height: 20px; flex-shrink: 0;
  }
  .notch-bars-big span {
    display: block; width: 3px; background: #1DB954; border-radius: 2px;
    animation: bar-bounce 0.8s ease-in-out infinite alternate;
  }
  .notch-bars-big span:nth-child(1) { height: 8px;  animation-delay: 0s; }
  .notch-bars-big span:nth-child(2) { height: 16px; animation-delay: 0.2s; }
  .notch-bars-big span:nth-child(3) { height: 11px; animation-delay: 0.1s; }
  .notch-bars-big span:nth-child(4) { height: 20px; animation-delay: 0.3s; }
  .notch-bars-big span:nth-child(5) { height: 13px; animation-delay: 0.15s; }
</style>
</head>
<body>

<!-- Notch Now Playing -->
<div id="notch" onclick="toggleNotch()">
  <div id="notch-collapsed">
    <div class="notch-bars">
      <span></span><span></span><span></span><span></span>
    </div>
    <div id="notch-title-mini"></div>
  </div>
  <div id="notch-expanded">
    <div id="notch-art">
      <svg viewBox="0 0 24 24"><path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z"/></svg>
    </div>
    <div id="notch-info">
      <div id="notch-song">—</div>
      <div id="notch-artist">—</div>
    </div>
    <div class="notch-bars-big">
      <span></span><span></span><span></span><span></span><span></span>
    </div>
  </div>
</div>

<div class="header">
  <div class="header-title"><span id="link-dot" class="link-dot"></span>Sintecla</div>
  <div class="battery" id="battery">
    <span id="batt-text">--%</span>
    <svg viewBox="0 0 24 24" style="width:20px;height:20px"><path d="M16 4h-2V2h-4v2H8C6.9 4 6 4.9 6 6v14c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm-1 10h-2v2h-2v-2H9v-2h2V8h2v2h2v2z"/></svg>
  </div>
</div>

<div class="trackpad-container" id="trackpad-container">
  <div id="pad"></div>
  <div id="fast-scroll">
    <div class="scroll-indicator"></div>
  </div>
</div>

<div class="input-wrapper">
  <input type="text" id="keyboard-input" placeholder="Escribe en el Mac…" autocomplete="off">
  <div id="btn-send"><svg viewBox="0 0 24 24"><path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z"/></svg></div>
</div>

<div class="controls-grid">
  <!-- Volume -->
  <div class="module mod-vol">
    <svg viewBox="0 0 24 24" style="width:18px;height:18px"><path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"/></svg>
    <input type="range" id="vol-slider" min="0" max="100" value="50">
  </div>

  <!-- Media -->
  <div class="mod-media">
    <div class="media-btn" data-action="backward10"><svg viewBox="0 0 24 24"><path d="M20 6v12l-8.5-6 8.5-6zm-9 0v12l-8.5-6 8.5-6z"/></svg></div>
    <div class="media-btn" data-action="play"><svg viewBox="0 0 24 24" style="width:32px;height:32px"><path d="M8 5v14l11-7z"/></svg></div>
    <div class="media-btn" data-action="forward10"><svg viewBox="0 0 24 24"><path d="M4 18l8.5-6L4 6v12zm9 0l8.5-6L13 6v12z"/></svg></div>
  </div>

  <!-- 4 Action Buttons -->
  <div class="module mod-btn" onclick="toggleMenu()">
    <svg viewBox="0 0 24 24"><path d="M3 18h18v-2H3v2zm0-5h18v-2H3v2zm0-7v2h18V6H3z"/></svg>
    Menú
  </div>
  <div class="module mod-btn" onclick="send({type:'key', name:'fullscreen'})">
    <svg viewBox="0 0 24 24"><path d="M7 14H5v5h5v-2H7v-3zm-2-4h2V7h3V5H5v5zm12 7h-3v2h5v-5h-2v3zM14 5v2h3v3h2V5h-5z"/></svg>
    Completa
  </div>
  <div class="module mod-btn" onclick="send({type:'tab', action:'close'})" style="color:var(--danger)">
    <svg viewBox="0 0 24 24" style="fill:var(--danger)"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></svg>
    Cerrar
  </div>
  <div class="module mod-btn" onclick="send({type:'system', action:'spotlight'})">
    <svg viewBox="0 0 24 24"><path d="M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"/></svg>
    Buscar
  </div>

  <!-- Clicks -->
  <div class="mod-clicks">
    <div class="click-btn" id="btn-left">Clic</div>
    <div class="click-btn" id="btn-right">Clic derecho</div>
  </div>
</div>

<!-- Overlay Menu -->
<div id="menu-overlay">
  <div class="menu-handle"></div>
  <div class="menu-titlebar">
    <div class="menu-title">Menú</div>
    <button class="menu-done" onclick="toggleMenu()">Listo</button>
  </div>

  <div class="menu-scroll">

    <div class="section-header">Trackpad</div>
    <div class="section-card">
      <div class="cell cell-vertical">
        <div class="cell-row">
          <span class="cell-label" style="font-size:15px">Sensibilidad</span>
          <span class="cell-value" id="sens-val" style="font-size:15px">2.2×</span>
        </div>
        <input type="range" id="sens-slider" class="slim-slider" min="0.5" max="5.0" step="0.1" value="2.2">
      </div>
    </div>

    <div class="section-header">Sistema</div>
    <div class="section-card">
      <div class="cell" onclick="send({type:'system', action:'spotlight'})">
        <div class="cell-icon" style="background:#5E5CE6">
          <svg viewBox="0 0 24 24"><path d="M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"/></svg>
        </div>
        <span class="cell-label">Spotlight</span>
        <span class="cell-chevron">›</span>
      </div>
      <div class="cell" onclick="send({type:'system', action:'screenshot'})">
        <div class="cell-icon" style="background:#30D158">
          <svg viewBox="0 0 24 24"><path d="M9 2L7.17 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2h-3.17L15 2H9zm3 15c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5z"/></svg>
        </div>
        <span class="cell-label">Captura de pantalla</span>
        <span class="cell-chevron">›</span>
      </div>
      <div class="cell">
        <div class="cell-icon" style="background:#FF9F0A">
          <svg viewBox="0 0 24 24"><path d="M12 7c-2.76 0-5 2.24-5 5s2.24 5 5 5 5-2.24 5-5-2.24-5-5-5zM2 13h2c.55 0 1-.45 1-1s-.45-1-1-1H2c-.55 0-1 .45-1 1s.45 1 1 1zm18 0h2c.55 0 1-.45 1-1s-.45-1-1-1h-2c-.55 0-1 .45-1 1s.45 1 1 1zM11 2v2c0 .55.45 1 1 1s1-.45 1-1V2c0-.55-.45-1-1-1s-1 .45-1 1zm0 18v2c0 .55.45 1 1 1s1-.45 1-1v-2c0-.55-.45-1-1-1s-1 .45-1 1z"/></svg>
        </div>
        <span class="cell-label">Brillo</span>
        <div class="stepper">
          <button class="stepper-btn" onclick="event.stopPropagation(); send({type:'system', action:'bright_down'})">−</button>
          <div class="stepper-sep"></div>
          <button class="stepper-btn" onclick="event.stopPropagation(); send({type:'system', action:'bright_up'})">+</button>
        </div>
      </div>
    </div>

    <div class="section-card" style="margin-top:8px">
      <div class="cell" onclick="if(confirm('¿Poner el Mac en reposo?')) { send({type:'system', action:'lock'}); toggleMenu(); }">
        <div class="cell-icon" style="background:#FF453A">
          <svg viewBox="0 0 24 24"><path d="M21.64 13a1 1 0 00-1.05-.14 8.05 8.05 0 01-3.37.73 8.15 8.15 0 01-8.14-8.1 8.59 8.59 0 01.25-2A1 1 0 008 2.36 10.14 10.14 0 1022 14.05a1 1 0 00-.36-1.05z"/></svg>
        </div>
        <span class="cell-label cell-danger">Reposo</span>
      </div>
    </div>

    <div class="section-header">Apps</div>
    <div class="section-card">
      <div class="cell" onclick="send({type:'app', name:'Safari'})">
        <div class="cell-icon" style="background:linear-gradient(180deg,#1E94FF,#0066CC)">
          <svg viewBox="0 0 24 24"><path d="M12 2a10 10 0 100 20 10 10 0 000-20zm0 18a8 8 0 110-16 8 8 0 010 16zm4.59-12.41L10 11l-3 6 6.41-3.59L17 7.59z"/></svg>
        </div>
        <span class="cell-label">Safari</span>
        <span class="cell-chevron">›</span>
      </div>
      <div class="cell" onclick="send({type:'app', name:'Spotify'})">
        <div class="cell-icon" style="background:#1DB954">
          <svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm4.59 14.41c-.18.3-.56.4-.86.22-2.37-1.45-5.36-1.78-8.87-.97-.34.08-.68-.13-.76-.47-.08-.34.13-.68.47-.76 3.84-.88 7.14-.51 9.81 1.12.3.18.4.56.21.86zm1.23-2.75c-.23.37-.71.49-1.08.26-2.72-1.67-6.86-2.16-10.07-1.18-.42.13-.86-.11-.99-.53-.13-.42.11-.86.53-.99 3.67-1.11 8.22-.57 11.34 1.35.37.23.49.71.27 1.09zm.1-2.85C14.69 8.93 9.45 8.74 6.4 9.66c-.49.15-1.01-.13-1.16-.62-.15-.49.13-1.01.62-1.16 3.51-1.07 9.27-.86 12.93 1.31.45.27.6.85.33 1.3-.27.46-.85.61-1.3.34z"/></svg>
        </div>
        <span class="cell-label">Spotify</span>
        <span class="cell-chevron">›</span>
      </div>
      <div class="cell" onclick="send({type:'app', name:'Finder'})">
        <div class="cell-icon" style="background:linear-gradient(180deg,#5AC8FA,#0A84FF)">
          <svg viewBox="0 0 24 24"><circle cx="9" cy="9" r="1.5"/><circle cx="15" cy="9" r="1.5"/><path d="M8 14.5c.7 1.2 2.2 2 4 2s3.3-.8 4-2" fill="none" stroke="#fff" stroke-width="1.6" stroke-linecap="round"/></svg>
        </div>
        <span class="cell-label">Finder</span>
        <span class="cell-chevron">›</span>
      </div>
    </div>

    <div class="section-header">Streaming</div>
    <div class="section-card">
      <div class="streaming-grid">
        <button class="streaming-btn" onclick="send({type:'open', url:'https://netflix.com'})" style="background:#E50914">Netflix</button>
        <button class="streaming-btn" onclick="send({type:'open', url:'https://youtube.com'})" style="background:#FF0000">YouTube</button>
        <button class="streaming-btn" onclick="send({type:'open', url:'https://primevideo.com'})" style="background:#1399FF">Prime</button>
        <button class="streaming-btn" onclick="send({type:'open', url:'https://disneyplus.com'})" style="background:#113CCF">Disney+</button>
        <button class="streaming-btn" onclick="send({type:'open', url:'https://hbomax.com'})" style="background:#7B2CBF">HBO</button>
        <button class="streaming-btn" onclick="send({type:'open', url:'https://tv.apple.com'})" style="background:#111">Apple TV+</button>
      </div>
    </div>

    <div class="section-header">Reposo programado</div>
    <div class="section-card">
      <div class="segmented">
        <button class="seg-btn active" id="timer-0" onclick="setTimer(0)">No</button>
        <button class="seg-btn" id="timer-15" onclick="setTimer(15)">15m</button>
        <button class="seg-btn" id="timer-30" onclick="setTimer(30)">30m</button>
        <button class="seg-btn" id="timer-60" onclick="setTimer(60)">60m</button>
      </div>
    </div>

    <div style="height:32px"></div>
  </div>
</div>

<script>
// ── WebSocket: persistent connection, zero HTTP overhead ──────────────
// La llave del enlace del QR: se guarda en el móvil y va en cada petición (la app de la pantalla de inicio no
// comparte las cookies de Safari).
const KEY = (() => {
  const fromLink = new URLSearchParams(location.search).get('k');
  try { if (fromLink) localStorage.setItem('k', fromLink); return fromLink || localStorage.getItem('k') || ''; }
  catch(e) { return fromLink || ''; }
})();
function withKey(path) { return path + (path.includes('?') ? '&' : '?') + 'k=' + encodeURIComponent(KEY); }

let ws = null;
let wsReady = false;
let wsReconnectTimer = null;

function connectWS() {
  try {
    ws = new WebSocket(`ws://${location.host}${withKey('/ws')}`);
  } catch(e) {
    scheduleReconnect();
    return;
  }
  ws.onopen = () => { wsReady = true; setLink(true); };
  ws.onclose = () => { wsReady = false; setLink(false); scheduleReconnect(); };
  ws.onerror = () => { try { ws.close(); } catch(e) {} };
}

function setLink(on) {
  document.getElementById('link-dot').classList.toggle('on', on);
}

function scheduleReconnect() {
  if (wsReconnectTimer) return;
  wsReconnectTimer = setTimeout(() => { wsReconnectTimer = null; connectWS(); }, 500);
}
connectWS();

function send(data) {
  if (wsReady && ws.readyState === 1) {
    try { ws.send(JSON.stringify(data)); return; } catch(e) {}
  }
  // HTTP fallback while WS is connecting
  try { navigator.sendBeacon(withKey('/action'), JSON.stringify(data)); } catch(e) {}
}

// ── Trackpad ──────────────────────────────────────────────────────────
const pad = document.getElementById('pad');
const padContainer = document.getElementById('trackpad-container');
let moveMultiplier = 2.2;
const MOVE_THRESHOLD = 3;

let lastX = 0, lastY = 0, startX = 0, startY = 0;
let twoFingerStartY = 0;
let hasMoved = false;
let fingers = 0;
let lastTapTime = 0;
const DOUBLE_TAP_MS = 300;

let pendingDx = 0, pendingDy = 0, pendingScroll = 0;
let rafPending = false;

function flushMove() {
  rafPending = false;
  if (pendingScroll !== 0) {
    send({ type: 'scroll', dy: pendingScroll });
    pendingScroll = 0;
  }
  if (pendingDx !== 0 || pendingDy !== 0) {
    send({ type: 'move', dx: pendingDx, dy: pendingDy });
    pendingDx = pendingDy = 0;
  }
}

function scheduleFlush() {
  if (!rafPending) {
    rafPending = true;
    requestAnimationFrame(flushMove);
  }
}

pad.addEventListener('touchstart', e => {
  e.preventDefault();
  padContainer.classList.add('active');
  fingers = e.touches.length;
  if (fingers === 1) {
    lastX = startX = e.touches[0].clientX;
    lastY = startY = e.touches[0].clientY;
    hasMoved = false;
  } else if (fingers === 2) {
    twoFingerStartY = (e.touches[0].clientY + e.touches[1].clientY) / 2;
  }
}, { passive: false });

pad.addEventListener('touchmove', e => {
  e.preventDefault();
  if (fingers === 1) {
    const cx = e.touches[0].clientX;
    const cy = e.touches[0].clientY;
    pendingDx += (cx - lastX) * moveMultiplier;
    pendingDy += (cy - lastY) * moveMultiplier;
    lastX = cx; lastY = cy;
    if (Math.abs(cx - startX) > MOVE_THRESHOLD || Math.abs(cy - startY) > MOVE_THRESHOLD) hasMoved = true;
  } else if (fingers === 2) {
    const cy = (e.touches[0].clientY + e.touches[1].clientY) / 2;
    const delta = cy - twoFingerStartY;
    if (Math.abs(delta) > 4) {
      pendingScroll += delta;
      twoFingerStartY = cy;
      hasMoved = true;
    }
  }
  scheduleFlush();
}, { passive: false });

pad.addEventListener('touchend', e => {
  e.preventDefault();
  padContainer.classList.remove('active');
  if (!hasMoved && fingers === 1) {
    const now = Date.now();
    const isDouble = (now - lastTapTime) < DOUBLE_TAP_MS;
    lastTapTime = isDouble ? 0 : now;
    send({ type: 'click', btn: 'left', double: isDouble });
  }
  fingers = e.touches.length;
}, { passive: false });

// ── Fast Scroll ─────────────────────────────────────────────────────────
const fastScroll = document.getElementById('fast-scroll');
let fsLastY = 0;

fastScroll.addEventListener('touchstart', e => {
  e.preventDefault();
  fsLastY = e.touches[0].clientY;
}, { passive: false });

fastScroll.addEventListener('touchmove', e => {
  e.preventDefault();
  const cy = e.touches[0].clientY;
  pendingScroll += (cy - fsLastY) * 4;
  fsLastY = cy;
  scheduleFlush();
}, { passive: false });

// ── Bottom controls ─────────────────────────────────────────────────────
document.getElementById('btn-left').addEventListener('click', () => send({ type: 'click', btn: 'left' }));
document.getElementById('btn-right').addEventListener('click', () => send({ type: 'click', btn: 'right' }));

document.getElementById('vol-slider').addEventListener('input', e => {
  send({ type: 'volume', value: e.target.value });
});

document.getElementById('btn-send').addEventListener('click', () => {
  const inp = document.getElementById('keyboard-input');
  send({ type: 'type', text: inp.value });
  inp.value = '';
});

// ── Media Buttons ───────────────────────────────────────────────────────
document.querySelectorAll('.media-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    send({ type: 'media', action: btn.getAttribute('data-action') });
  });
});

// ── Menu overlay ────────────────────────────────────────────────────────
const menuOverlay = document.getElementById('menu-overlay');

function toggleMenu() {
  menuOverlay.classList.toggle('open');
}

function setTimer(mins) {
  document.querySelectorAll('.seg-btn').forEach(b => b.classList.remove('active'));
  document.getElementById(`timer-${mins}`).classList.add('active');
  send({ type: 'timer', minutes: mins });
  setTimeout(toggleMenu, 300);
}

// ── Sensitivity ─────────────────────────────────────────────────────────
document.getElementById('sens-slider').addEventListener('input', e => {
  moveMultiplier = parseFloat(e.target.value);
  document.getElementById('sens-val').textContent = moveMultiplier.toFixed(1) + '×';
});

// ── Battery polling ─────────────────────────────────────────────────────
function updateStatus() {
  fetch(withKey('/status'))
    .then(r => r.json())
    .then(data => {
      const batText = document.getElementById('batt-text');
      const battery = document.getElementById('battery');
      batText.textContent = `${data.battery}%`;
      if (data.charging) {
        battery.style.color = '#34c759';
      } else if (data.battery < 20) {
        battery.style.color = 'var(--danger)';
      } else {
        battery.style.color = 'var(--text-muted)';
      }
    })
    .catch(() => {});
}
setInterval(updateStatus, 10000);
updateStatus();

// ── Now Playing Notch ────────────────────────────────────────────────────
const notch = document.getElementById('notch');
let notchExpanded = false;
let lastTrack = '';
let autoCollapseTimer = null;

function toggleNotch() {
  notchExpanded = !notchExpanded;
  notch.classList.toggle('expanded', notchExpanded);
  if (notchExpanded) {
    clearTimeout(autoCollapseTimer);
    autoCollapseTimer = setTimeout(() => {
      notchExpanded = false;
      notch.classList.remove('expanded');
    }, 6000);
  }
}

function updateNowPlaying() {
  fetch(withKey('/nowplaying'))
    .then(r => r.json())
    .then(data => {
      if (!data.playing) {
        notch.classList.remove('visible');
        return;
      }
      notch.classList.add('visible');

      document.getElementById('notch-title-mini').textContent = data.title;
      document.getElementById('notch-song').textContent = data.title;
      document.getElementById('notch-artist').textContent = data.artist;

      const artEl = document.getElementById('notch-art');
      if (data.artwork) {
        artEl.innerHTML = `<img src="${withKey(data.artwork)}" alt="">`;
      } else {
        artEl.innerHTML = `<svg viewBox="0 0 24 24"><path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z"/></svg>`;
      }

      const track = data.title + data.artist;
      if (track !== lastTrack) {
        lastTrack = track;
        notchExpanded = true;
        notch.classList.add('expanded');
        clearTimeout(autoCollapseTimer);
        autoCollapseTimer = setTimeout(() => {
          notchExpanded = false;
          notch.classList.remove('expanded');
        }, 5000);
      }
    })
    .catch(() => {});
}
setInterval(updateNowPlaying, 3000);
updateNowPlaying();
</script>
</body>
</html>
"""#
}
