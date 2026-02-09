# Locode — QR Phishing Shield

Locode protects users from QR code phishing attacks ("quishing") using a two-phase detection system powered by Gemini 3 Flash.

## How It Works

1. **Passive Protection:** Set Locode as your default browser. When you scan a QR code with your native camera, Locode intercepts the URL and shows a safety verdict as a heads-up notification — without leaving the camera.

2. **Active Scanning:** Open Locode and use the built-in QR scanner to check any code manually.

3. **Community Heatmap:** See real-time scam reports on a map of your city. Locode ships with verified parking lot data for Savannah, GA.

## Architecture
Native Camera → QR URL → Locode intercepts → Kotlin heuristic engine
→ Heads-up notification verdict
In-App Scanner → QR URL → Local Dart heuristics (instant)
→ Gemini 3 Flash API (deep analysis)
→ Two-phase verdict display

## Tech Stack

- **Flutter (Dart)** — Cross-platform UI
- **Gemini 3 Flash** — AI-powered URL analysis with multimodal context
- **Kotlin** — Native Android URL interception & heuristic engine
- **Supabase** — Real-time scam report database
- **Google Maps SDK + Places API v1** — Threat heatmap & parking lot visualization
- **Clean Architecture** — Domain-driven design with BLoC state management

## Gemini 3 Integration

Locode uses an autonomous Gemini 3 Flash agent for deep URL analysis:

- Resolves full redirect chains before evaluating the final destination
- Analyzes URL structure, domain reputation, and phishing indicators
- Evaluates physical context (GPS location near known scam hotspots)
- Returns a structured verdict (safe / suspicious / danger) with confidence score and reasoning
- Anti-prompt-injection safeguards prevent URL-embedded attacks

## Setup for Camera Interception

1. Install Locode on an Android device
2. Go to **Settings → Apps → Default Apps → Browser → select Locode**
3. Allow notification permission when prompted
4. Scan any QR code with the native camera — Locode will intercept and analyze
