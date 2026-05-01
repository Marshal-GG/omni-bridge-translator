type Engine = {
  name: string
  desc: string
  tag: string
  recommended?: boolean
}

const asr: Engine[] = [
  {
    name: 'NVIDIA Riva',
    desc: 'High-accuracy multilingual streaming ASR. Free API key from build.nvidia.com.',
    tag: 'cloud',
    recommended: true,
  },
  {
    name: 'Whisper Offline',
    desc: 'Tiny, Base, Small, Medium — downloadable from Settings. Privacy-first, works without internet.',
    tag: 'on-device',
  },
  {
    name: 'Google Online',
    desc: 'Zero setup, fast, broad language coverage. Free tier daily quota applies.',
    tag: 'cloud',
  },
]

const nmt: Engine[] = [
  {
    name: 'Llama 3.1 8B',
    desc: 'AI-powered, context-aware translation hosted on NVIDIA. Best quality for nuanced text.',
    tag: 'cloud',
    recommended: true,
  },
  {
    name: 'Google Translate',
    desc: 'Free, fast, 100+ languages, no setup. Solid baseline for everyday use.',
    tag: 'cloud',
  },
  {
    name: 'Google Cloud v3',
    desc: 'Professional gRPC translation. Bring your own service-account JSON for production-grade quality.',
    tag: 'cloud',
  },
  {
    name: 'NVIDIA Riva NMT',
    desc: 'High-quality neural translation paired naturally with Riva ASR for low-latency pipelines.',
    tag: 'cloud',
  },
  {
    name: 'MyMemory',
    desc: 'Free fallback engine, no API key needed. Useful when other engines are rate-limited.',
    tag: 'cloud',
  },
]

function Group({ title, kind, items }: { title: string; kind: 'asr' | 'nmt'; items: Engine[] }) {
  return (
    <div className="engine-group">
      <div className="engine-group-header">
        <p className={`engine-group-title ${kind}`}>{title}</p>
        <span className="engine-pill">{items.length} engines</span>
      </div>
      {items.map((e) => (
        <div className="engine-row" key={e.name}>
          <div>
            <div className="engine-name">
              {e.name}
              {e.recommended && <span className="recommended">★ Recommended</span>}
            </div>
            <div className="engine-desc">{e.desc}</div>
          </div>
          <div className="engine-tag">{e.tag}</div>
        </div>
      ))}
    </div>
  )
}

export default function Engines() {
  return (
    <section className="section" id="engines">
      <div className="section-header">
        <p className="section-label">Engines</p>
        <h2 className="section-title">Pick the engine that fits the job</h2>
        <p className="section-desc">
          Speech recognition and translation are decoupled — mix any pair. Bring your own NVIDIA key
          to bypass quotas on Riva and Llama engines.
        </p>
      </div>

      <div className="engines-wrap">
        <Group title="Speech recognition" kind="asr" items={asr} />
        <Group title="Translation" kind="nmt" items={nmt} />
      </div>
    </section>
  )
}
