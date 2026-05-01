const CHECK = (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
    <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z" />
  </svg>
)

export default function Pricing() {
  return (
    <section id="pricing" className="section">
      <div className="section-header">
        <p className="section-label">Pricing</p>
        <h2 className="section-title">Free forever, scale when you need it</h2>
        <p className="section-desc">
          Token-based quotas across all engines. Bring your own NVIDIA API key to bypass quotas on
          NVIDIA-backed engines on any tier.
        </p>
      </div>

      <div className="pricing-grid">
        {/* Free */}
        <div className="pricing-card">
          <h3 className="pricing-tier">Free</h3>
          <div className="pricing-price">
            <span className="pricing-currency">₹</span>0
            <span className="pricing-period">/forever</span>
          </div>
          <p className="pricing-desc">
            Get started with live captions. Daily quota resets every 24h.
          </p>
          <ul className="pricing-features">
            <li className="pricing-feature">{CHECK}5,000 tokens / day · 50,000 / month</li>
            <li className="pricing-feature">{CHECK}Google Translate &amp; MyMemory</li>
            <li className="pricing-feature">{CHECK}Google Online ASR</li>
            <li className="pricing-feature">{CHECK}15-minute session limit</li>
          </ul>
          <a
            href="https://github.com/Marshal-GG/omni-bridge-translator/releases/latest"
            target="_blank"
            rel="noopener noreferrer"
            className="btn btn-secondary pricing-action"
          >
            Download Free
          </a>
        </div>

        {/* Pro — featured */}
        <div className="pricing-card featured">
          <div className="pricing-badge">Most Popular</div>
          <h3 className="pricing-tier">Pro</h3>
          <div className="pricing-price">
            <span className="pricing-currency">₹</span>799
            <span className="pricing-period">/mo</span>
          </div>
          <p className="pricing-desc">
            Everyday users. All translation engines, Whisper Tiny–Small, microphone audio.
          </p>
          <ul className="pricing-features">
            <li className="pricing-feature">{CHECK}25,000 tokens / day · 250,000 / month</li>
            <li className="pricing-feature">{CHECK}All translation engines</li>
            <li className="pricing-feature">{CHECK}Whisper Tiny / Base / Small</li>
            <li className="pricing-feature">{CHECK}Microphone capture</li>
            <li className="pricing-feature">{CHECK}7-day caption history</li>
            <li className="pricing-feature">{CHECK}2-hour sessions, 2 concurrent</li>
          </ul>
          <a
            href="https://github.com/Marshal-GG/omni-bridge-translator/releases/latest"
            target="_blank"
            rel="noopener noreferrer"
            className="btn btn-primary pricing-action"
          >
            Get Pro
          </a>
          <div className="pricing-foot">Activate inside the app · cancel anytime</div>
        </div>

        {/* Enterprise */}
        <div className="pricing-card">
          <h3 className="pricing-tier">Enterprise</h3>
          <div className="pricing-price">
            <span className="pricing-currency">₹</span>2,499
            <span className="pricing-period">/mo</span>
          </div>
          <p className="pricing-desc">
            Power users &amp; teams. Highest accuracy ASR, longest sessions, generous concurrency.
          </p>
          <ul className="pricing-features">
            <li className="pricing-feature">{CHECK}75,000 tokens / day · 750,000 / month</li>
            <li className="pricing-feature">{CHECK}Whisper Medium + NVIDIA Riva</li>
            <li className="pricing-feature">{CHECK}30-day caption history</li>
            <li className="pricing-feature">{CHECK}8-hour sessions, 5 concurrent</li>
            <li className="pricing-feature">{CHECK}Priority support</li>
          </ul>
          <a
            href="https://github.com/Marshal-GG/omni-bridge-translator/releases/latest"
            target="_blank"
            rel="noopener noreferrer"
            className="btn btn-secondary pricing-action"
          >
            Get Enterprise
          </a>
          <div className="pricing-foot">A free Trial tier is available for new accounts</div>
        </div>
      </div>
    </section>
  )
}
