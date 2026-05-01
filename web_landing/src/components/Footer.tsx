export default function Footer() {
  return (
    <footer className="footer">
      <div className="footer-inner">
        <div>
          <div className="footer-brand">
            Omni <span>Bridge</span>
          </div>
          <div className="footer-tagline">
            Real-time speech translation for Windows · © {new Date().getFullYear()} Marshal-GG
          </div>
        </div>

        <ul className="footer-links">
          <li>
            <a
              href="https://github.com/Marshal-GG/omni-bridge-translator"
              target="_blank"
              rel="noopener noreferrer"
            >
              GitHub
            </a>
          </li>
          <li><a href="#features">Features</a></li>
          <li><a href="#pricing">Pricing</a></li>
          <li>
            <a
              href="https://github.com/Marshal-GG/omni-bridge-translator/releases"
              target="_blank"
              rel="noopener noreferrer"
            >
              Changelog
            </a>
          </li>
          <li>
            <a
              href="https://github.com/Marshal-GG/omni-bridge-translator/issues/new?labels=bug"
              target="_blank"
              rel="noopener noreferrer"
            >
              Report a bug
            </a>
          </li>
        </ul>
      </div>
    </footer>
  )
}
