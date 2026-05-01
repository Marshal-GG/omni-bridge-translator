import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Omni Bridge — Real-time AI Speech Translation for Windows',
  description:
    'Capture any audio playing on your PC or microphone, translate it instantly with NVIDIA Riva, Whisper, or Llama 3.1, and watch it as a transparent always-on-top overlay. Windows desktop app.',
  metadataBase: new URL('https://omnibridge.marshalx.dev'),
  openGraph: {
    title: 'Omni Bridge — Real-time AI Speech Translation',
    description:
      'Live captions and translations for any audio on your Windows PC. Riva · Whisper · Llama 3.1.',
    url: 'https://omnibridge.marshalx.dev',
    siteName: 'Omni Bridge',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Omni Bridge — Real-time AI Speech Translation',
    description:
      'Live captions and translations for any audio on your Windows PC. Riva · Whisper · Llama 3.1.',
  },
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link
          href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;600&display=swap"
          rel="stylesheet"
        />
      </head>
      <body>{children}</body>
    </html>
  )
}
