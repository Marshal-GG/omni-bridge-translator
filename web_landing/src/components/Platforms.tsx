const platforms = [
  {
    title: 'Windows 10 / 11',
    sub: '64-bit · ~200 MB installer',
    desc: 'Single Inno Setup installer. Bundles the Python server and Flutter UI — survives upgrades, keeps your Whisper models, and signs you back in automatically.',
    status: 'live' as const,
  },
  {
    title: 'NVIDIA GPU (optional)',
    sub: 'Unlocks Riva acceleration',
    desc: 'Any modern NVIDIA card unlocks low-latency Riva ASR / NMT engines. CPU-only systems still work — engines fall back to cloud or Whisper.',
    status: 'live' as const,
  },
  {
    title: 'macOS / Linux',
    sub: 'Tracking interest',
    desc: 'Cross-platform builds aren&apos;t on the v2 roadmap. If you&apos;d like to see them, open a GitHub issue with your use case.',
    status: 'soon' as const,
  },
]

export default function Platforms() {
  return (
    <div className="platforms" id="download">
      <div className="platforms-inner">
        <div className="section-header">
          <p className="section-label">Download</p>
          <h2 className="section-title">Built for Windows desktop</h2>
          <p className="section-desc">
            One installer, no separate runtime to manage. Updates land via the in-app updater — no
            store, no sideloading.
          </p>
        </div>

        <div className="platform-cards">
          {platforms.map((p) => (
            <div className="platform-card" key={p.title}>
              <div>
                <div className="platform-card-title">{p.title}</div>
                <div className="platform-card-sub">{p.sub}</div>
              </div>
              <p className="feature-desc" dangerouslySetInnerHTML={{ __html: p.desc }} />
              {p.status === 'live' && <span className="badge-live">Available now</span>}
              {p.status === 'soon' && <span className="badge-soon">Tracking interest</span>}
            </div>
          ))}
        </div>

        <div style={{ textAlign: 'center', marginTop: '2.5rem' }}>
          <a
            href="https://github.com/Marshal-GG/omni-bridge-translator/releases/latest"
            target="_blank"
            rel="noopener noreferrer"
            className="btn btn-primary btn-lg"
          >
            Download latest release
          </a>
        </div>
      </div>
    </div>
  )
}
