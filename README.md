# 🏆 DebateFlow 2026

**DebateFlow** is a high-performance, real-time tournament management system built with Flutter and Firebase. Designed for WSDC, BP, and Asian Parliamentary formats, it handles everything from participant registration to power-paired matchups and live ballot adjudication.

---

## 🚀 Key Features

* **Real-time Lobby:** Create and manage multiple tournaments under one admin account.
* **Intelligent Pairings:** Automatic power-pairing based on wins and total speaker marks.
* **Live Ballots:** Digital adjudication with built-in "Ironman" logic and dynamic score ranges.
* **Theatrical Reveals:** Cinematic motion reveal screens with synchronized countdown timers.
* **Dynamic Standings:** Instant calculation of team rankings and speaker breaks.
* **Public Results:** Live-streaming results via a public-facing results board.

---

## 🛠️ Project Structure

```text
lib/
├── models/         # Data structures (Ballots, Teams, Users)
├── screens/        # UI Layers (Auth, Pairings, Setup, etc.)
├── services/       # Business Logic (Auth, Matchmaking, Standings)
├── widgets/        # Reusable UI components (Overview cards)
└── main.dart       # App entry point & Theme configuration