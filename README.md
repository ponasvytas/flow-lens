# Flow Lens

A multi-sport video analysis tool for coaches. Record events, draw annotations on video, and review plays frame-by-frame. Built with Flutter — runs on web, desktop, and mobile.

## Features

- **Three modes**: Record events during playback, Review with drawings and navigation, and more coming soon
- **Event tagging**: Customizable sport taxonomies with keyboard-driven workflows (Alt+number combos)
- **Drawing tools**: Freehand, lines, arrows, and laser pointer overlays on video
- **Dock workspace**: Explicit docking, resizable non-overlapping edge regions,
  per-workflow layouts, and overlay or squeeze-video presentation
- **Keyboard shortcuts**: Full playback control, speed changes, and event entry without leaving the keyboard
- **Cross-platform**: Web, Windows, macOS, Linux, iOS, Android

## Getting Started

```bash
flutter pub get
flutter run
```

## Local development: accounts and challenges

Use this setup to test accounts and challenges on your computer without cloud
billing. Plain `flutter run` uses the live Firebase project instead.

### First-time setup

Install Flutter, Node.js (22 recommended), the Firebase CLI, and Java 21 or newer.
From the repository root, install the app and backend dependencies:

```powershell
flutter pub get
npm.cmd --prefix functions ci
```

The backend launcher also recognizes the Java runtime in `.local/challenge-jre`
if it was installed during setup on this computer.

### Start a session

Open two PowerShell terminals in the repository root. In **terminal 1**, start
the backend and wait for **All emulators ready**. Keep this terminal running:

```powershell
.\scripts\start-local-backend.ps1
```

In **terminal 2**, start the app and keep this terminal running:

```powershell
.\scripts\start-local-app.ps1
```

Open http://127.0.0.1:54321/ and check for the **LOCAL** banner. Create a **local
test account**; your live Firebase account is separate. Use a second browser
profile or private window to test as a player. Local invitation links work on
this computer only.

The emulator dashboard at http://127.0.0.1:4000/ lets you inspect local accounts
and challenge data.

### Stop and resume

1. In the app terminal, press **q** to stop Flutter.
2. In the backend terminal, press **Ctrl+C once** and wait for the data export
   and shutdown to finish.

Local accounts and challenges are saved to `.local/firebase-data` and restored
the next time you run the backend launcher. Closing or killing the backend
before export finishes can lose changes. Run the same two launch commands to
resume later. If a port is already in use, check for an existing session before
starting another.

### What belongs in Git

Commit this README, the [detailed development guide](specs/challenges/README.md),
the two scripts in `scripts/`, and the related app/backend configuration and code
so this setup is available after a fresh checkout. Creating a Git commit does
not deploy the app or enable billing.

Keep `.local/` out of Git. It contains machine-specific runtimes, emulator exports,
and potentially test credentials and answer keys. The repository already ignores
this directory; backend dependencies in `functions/node_modules/` are also ignored.

See [local setup and testing](specs/challenges/README.md#local-development-without-billing)
for other platforms, manual exports, and verification commands.
