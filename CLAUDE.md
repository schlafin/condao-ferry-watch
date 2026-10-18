# Con Dao Ferry Watch — Claude Code project brief

Read `condao-ferry-watch-design.md` in this folder first — that's the
full spec. This file is just the short, every-session context Claude
Code should hold onto without being re-told.

## Why this project exists

This is primarily a **learning project**, not a product. The ferry
watcher is a realistic, low-stakes example for Michael to learn:

1. **Git and GitHub** — commits, version history, reverting, pushing,
   and running scheduled jobs in the cloud with **GitHub Actions** so
   nothing depends on his Mac being on.
2. **Xcode and macOS app development** — building, signing and running
   a small native Mac app.

The core thing being tested is the end-to-end chain: a **scheduled
GitHub Action produces data and that data reaches the macOS app**
(fetched `state.json`, and later push notifications).

When choosing between options, favor the one that teaches the
GitHub/Xcode workflow clearly over the one that makes the ferry
forecast more accurate. Keep the weather/scoring logic as simple as
possible until the pipeline works end to end. Explain git, GitHub and
Xcode steps as you do them — Michael wants to understand them, while
Claude handles the GitHub side (commits, pushes, workflows) for him.

## What it does

A personal tool for Michael that watches sea conditions along the Vung
Tau ⇄ Con Dao ferry route (a specific vessel, "Thăng Long," operated by
Phú Quốc Express) and pushes a native macOS notification when an
upcoming scheduled departure looks smooth enough to book. Single user,
not a product — optimize for correctness and low maintenance, not
generality or polish.

## Current status (update this section as work progresses)

- GitHub repo is **public** at
  https://github.com/schlafin/condao-ferry-watch, local copy at
  `~/Claude/Projects/condao-ferry-watch`. Work goes on a branch → PR →
  merge (Michael chose this to learn the PR flow).
- **Milestone 1 (local notifications, no APNs) works end to end**, verified
  2026-10-18: workflow run → bot commits `state.json` → Mac app fetches it
  → macOS notification.
  - Backend: `backend/` (run locally with
    `.venv/bin/python backend/main.py [--test-event]`); workflow at
    `.github/workflows/ferry-check.yml`, every 6h plus a manual trigger
    with a `test_event` checkbox. `state.json` at the repo root holds
    `departures` (latest ratings) and `events` (rating changes from this
    run, each with a unique `id`). A first-time rating only makes an event
    if it isn't RED.
  - Mac app: Xcode project in `ConDaoFerryWatch/` (SwiftUI `MenuBarExtra`,
    menu-bar only, signed with Michael's free Personal Team, App Sandbox +
    outgoing network). Fetches the raw `state.json` at launch, every 30
    min, and whenever the dropdown opens; posts each unseen event as a
    local notification. It never computes ratings.
  - Known limits: events last only until the next run (6h), so a Mac
    asleep longer misses them (fixed by APNs in milestone 2). One run
    failed on an Open-Meteo read timeout; there is no retry yet.
- **Next: milestone 2, APNs push** (needs the $99 Apple Developer Program,
  a .p8 key and the five GitHub secrets; design doc §6, §10).
- The GitHub CLI login now has the `workflow` scope (needed to push files
  under `.github/workflows/`).
- `reference-sketch/` is the old untested v1 draft, now superseded by
  `backend/` and `ConDaoFerryWatch/`; its README is out of date. The
  design doc wins.

## Hold onto these — easy to accidentally drift from across sessions

- Data source is **Open-Meteo** (free, keyless marine + weather APIs).
  Never Windy — its API isn't viable for automation (design doc §3).
- Route/path model: **7 waypoints** along the route, each queried at its
  own ETA-adjusted forecast hour (not "now" for every point), scored,
  and aggregated as **worst-waypoint-wins** per departure — not an
  average, not a single point.
- **No automated route-active gate and no automated live check** of the
  ferry operator's booking/status site. This was a deliberate decision
  (design doc §2), not a missing feature — don't add either without
  checking with Michael first.
- Notification on/off is controlled by Michael at the **macOS System
  Settings** level, not by any flag or toggle in this codebase.
- APNs defaults to the **sandbox** endpoint, matching a plain Xcode
  Debug build. Don't switch to production without confirming there's an
  actual signed release build to match it.
- **iOS is explicitly deferred.** Build macOS only unless told
  otherwise; don't add an iOS target speculatively.
- The repo is public specifically so the macOS app can fetch
  `state.json` with a plain unauthenticated request. Don't reintroduce
  a token-based fetch without a reason.

## Working style

Michael prefers direct, precise answers over reassurance, and removing
complexity before adding it — don't over-build. He's technical (builds
his own equity research/valuation pipelines) but new to git/GitHub,
Xcode, and the Apple developer ecosystem specifically — go step by step
on those parts rather than assuming familiarity, the same way this
project's design conversation did.
