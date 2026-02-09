# SafeScan — QR Phishing Shield

SafeScan protects users from QR code phishing attacks ("quishing") using a two-phase detection system powered by Gemini 3.

## How It Works

1. **Passive Protection:** Set SafeScan as your default browser. When you scan a QR code with your native camera, SafeScan intercepts the URL and shows a safety verdict as a heads-up notification — without leaving the camera.

2. **Active Scanning:** Open SafeScan and use the built-in QR scanner to check any code manually.

3. **Community Heatmap:** See real-time scam reports on a map of your city. SafeScan ships with verified parking lot data for Savannah, GA.

## Architecture

```
Native Camera → QR URL → SafeScan intercepts → Kotlin heuristic engine
                                              → Heads-up notification verdict
                                              
In-App Scanner → QR URL → Local Dart heuristics (instant)
                        → Gemini 3 Flash API (deep analysis)
                        → Two-phase verdict display
```

## Tech Stack

- **Flutter** (Dart) — Cross-platform UI
- **Gemini 3 Flash** — AI-powered URL analysis with multimodal context
- **Kotlin** — Native Android URL interception & heuristic engine
- **Supabase** — Real-time scam report database
- **Google Maps** — Threat heatmap visualization
- **Clean Architecture** — Domain-driven design with BLoC state management

## Gemini 3 Integration

SafeScan uses `gemini-3-flash-preview` for deep URL analysis:
- Analyzes URL structure, redirect chains, and domain reputation
- Evaluates physical context (GPS location near known scam hotspots)
- Returns structured JSON verdict with confidence score and reasoning
- Anti-prompt-injection safeguards prevent URL-embedded attacks

## Building

```bash
flutter run \
  --dart-define=GEMINI_API_KEY=<your_key> \
  --dart-define=SUPABASE_URL=<your_url> \
  --dart-define=SUPABASE_ANON_KEY=<your_key> \
  --dart-define=GOOGLE_MAPS_API_KEY=<your_key>
```

## Setup for Camera Interception

1. Install SafeScan on an Android device
2. Go to Settings → Apps → Default Apps → Browser → select SafeScan
3. Allow notification permission when prompted
4. Scan any QR code with the native camera — SafeScan will intercept and analyze