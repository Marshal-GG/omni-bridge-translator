const features = [
  {
    icon: '🎙️',
    title: 'Universal audio capture',
    desc: 'Translates any audio playing on your PC — videos, calls, streams, meetings — or your microphone. One-toggle switch with independent volume controls.',
  },
  {
    icon: '🌐',
    title: 'Multi-engine ASR',
    desc: 'Pick NVIDIA Riva for highest accuracy, Whisper for offline privacy, or Google for zero-setup speed. Switch any time without restarting.',
  },
  {
    icon: '🔤',
    title: 'Multi-engine translation',
    desc: 'Llama 3.1 8B for context-aware AI translation, Google Translate for breadth, or Riva NMT for neural quality. Bring your own NVIDIA key for unlimited.',
  },
  {
    icon: '🪟',
    title: 'Transparent overlay',
    desc: 'Always-on-top, draggable, resizable. Adjustable opacity, font size, bold toggle, and a Mini Mode that collapses to a single caption line.',
  },
  {
    icon: '📜',
    title: 'Searchable history',
    desc: 'Every caption is saved to a glassy dark History Panel — search, jump back, and copy any line. Retention scales with your tier.',
  },
  {
    icon: '☁️',
    title: 'Account &amp; sync',
    desc: 'Sign in with Google, email, or as Guest. Settings sync across devices. Live usage dashboard, real-time quota tracking, Razorpay-powered billing.',
  },
]

export default function Features() {
  return (
    <section className="section" id="features">
      <div className="section-header">
        <p className="section-label">Features</p>
        <h2 className="section-title">Everything you need, nothing you don&apos;t</h2>
        <p className="section-desc">
          Built for live captions that follow what you&apos;re actually doing — gaming, meetings, foreign-language content, accessibility.
        </p>
      </div>

      <div className="features-grid">
        {features.map((f) => (
          <div className="feature-card" key={f.title}>
            <div className="feature-icon">{f.icon}</div>
            <h3 className="feature-title" dangerouslySetInnerHTML={{ __html: f.title }} />
            <p className="feature-desc" dangerouslySetInnerHTML={{ __html: f.desc }} />
          </div>
        ))}
      </div>
    </section>
  )
}
