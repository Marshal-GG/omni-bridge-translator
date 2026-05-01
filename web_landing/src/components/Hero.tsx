const CHECK = (
  <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
    <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z" />
  </svg>
)

export default function Hero() {
  return (
    <section className="hero">
      <div className="hero-badge">
        <span className="hero-badge-dot" />
        Live on your desktop
      </div>

      <h1 className="hero-title">
        Real-time speech translation,<br />
        <span className="gradient">right on your desktop.</span>
      </h1>

      <p className="hero-subtitle">
        Capture any audio playing on your PC or microphone, translate it instantly with
        NVIDIA Riva, Whisper, or Llama 3.1, and watch it appear as a transparent
        always-on-top overlay. No extra hardware. No browser tabs.
      </p>

      <div className="hero-actions">
        <a
          href="https://github.com/Marshal-GG/omni-bridge-translator/releases/latest"
          target="_blank"
          rel="noopener noreferrer"
          className="btn btn-primary btn-lg"
        >
          Download for Windows
        </a>
        <a
          href="https://github.com/Marshal-GG/omni-bridge-translator"
          target="_blank"
          rel="noopener noreferrer"
          className="btn btn-secondary btn-lg"
        >
          View on GitHub
        </a>
      </div>

      <div className="hero-meta">
        <span className="hero-meta-item">{CHECK} 20+ languages, auto-detect</span>
        <span className="hero-meta-item">{CHECK} System audio &amp; microphone</span>
        <span className="hero-meta-item">{CHECK} Works offline (Whisper)</span>
      </div>

      {/* live caption preview — supporting visual */}
      <div className="caption-preview" aria-hidden="true">
        <div className="caption-row">
          <span className="caption-lang">JA</span>
          <span className="caption-text dim">こんにちは、今日の会議を始めましょう。</span>
        </div>
        <div className="caption-row">
          <span className="caption-lang target">EN</span>
          <span className="caption-text">Hello, let&apos;s start today&apos;s meeting.</span>
        </div>
        <div className="caption-row">
          <span className="caption-lang">ES</span>
          <span className="caption-text dim">El proyecto está listo para revisión.</span>
        </div>
        <div className="caption-row">
          <span className="caption-lang target">EN</span>
          <span className="caption-text">The project is ready for review.</span>
        </div>
      </div>
    </section>
  )
}
