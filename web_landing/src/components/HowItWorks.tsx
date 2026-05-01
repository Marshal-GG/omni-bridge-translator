const steps = [
  {
    n: '1',
    title: 'Install',
    desc: 'Download OmniBridge_Setup.exe from the Releases page. The installer bundles the Python server and Flutter UI — no separate setup, no Docker.',
  },
  {
    n: '2',
    title: 'Sign in',
    desc: 'Sign in with Google or email — or continue as Guest. Settings sync to the cloud the moment you log in.',
  },
  {
    n: '3',
    title: 'Pick engines &amp; language',
    desc: 'In Settings → choose a speech recognition engine, a translation engine, and your target language. Defaults work out of the box.',
  },
  {
    n: '4',
    title: 'Hit play',
    desc: 'Captions appear live as audio plays on your PC. Drag the overlay anywhere, resize it, collapse it to Mini Mode for a single line.',
  },
]

export default function HowItWorks() {
  return (
    <section className="section" id="how-it-works">
      <div className="section-header">
        <p className="section-label">How it works</p>
        <h2 className="section-title">From install to live captions in minutes</h2>
        <p className="section-desc">
          No configuration wizards. No browser extensions. Install, sign in, pick your engines, done.
        </p>
      </div>

      <div className="steps">
        {steps.map((s) => (
          <div className="step" key={s.n}>
            <div className="step-number">{s.n}</div>
            <div>
              <h3 className="step-title" dangerouslySetInnerHTML={{ __html: s.title }} />
              <p className="step-desc">{s.desc}</p>
            </div>
          </div>
        ))}
      </div>
    </section>
  )
}
