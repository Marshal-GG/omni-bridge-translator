export default function Navbar() {
  return (
    <header className="navbar">
      <div className="navbar-logo">
        <span className="navbar-logo-dot" />
        Omni <span>Bridge</span>
      </div>

      <nav>
        <ul className="navbar-links">
          <li><a href="#features">Features</a></li>
          <li><a href="#engines">Engines</a></li>
          <li><a href="#how-it-works">How it works</a></li>
          <li><a href="#pricing">Pricing</a></li>
          <li><a href="#download">Download</a></li>
        </ul>
      </nav>

      <div className="navbar-actions">
        <a
          href="https://github.com/Marshal-GG/omni-bridge-translator"
          target="_blank"
          rel="noopener noreferrer"
          className="btn btn-secondary"
        >
          GitHub
        </a>
        <a
          href="https://github.com/Marshal-GG/omni-bridge-translator/releases/latest"
          target="_blank"
          rel="noopener noreferrer"
          className="btn btn-primary"
        >
          Download
        </a>
      </div>
    </header>
  )
}
