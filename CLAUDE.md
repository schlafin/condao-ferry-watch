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
    asleep longer misses them (fixed by APNs in milestone 2). Open-Meteo's
    marine server has brief outages; requests retry up to 3 times (PR #3),
    and a run that still fails leaves the previous `state.json` in place.
- **Direction (2026-10-18): go as far as possible on the free tier first.**
  APNs ($99) is deferred until Michael decides he needs alerts while the
  app is closed. Planned free-tier PRs, in order D → A → B → C:
  - **PR A, real Mac app:** normal window app installed in Applications
    (Archive → Copy App). A "Show in menu bar" setting (off by default)
    controls background mode: on = keeps running with a menu-bar icon,
    checks every 30 min, notifies, and offers Launch at login; off =
    closing the window quits, and the app updates only while open. Nothing
    runs invisibly. In open-only mode, mark departures that "changed since
    you last looked". Clicking a notification opens the window.
    **Drill-down:** clicking a departure expands it to show every point's
    score along the path and the biggest contributors (data comes from
    PR D's per-point detail in `state.json`).
  - **PR B, desktop widget** (WidgetKit) with a Refresh button and no
    automatic refresh.
  - Optional PR C: Shortcuts/Siri action (App Intents).
- **PR D, in progress on branch `scoring-v2`** (backend only; the current
  app ignores the new fields):
  1. **Explicit route-side endpoint cells.** Open-Meteo's marine model is a
     1/12° (~9.2 km) grid, and its default `cell_selection=sea` silently
     moves land requests to the nearest sea cell. Verified 2026-10-18:
     Cầu Đá snaps to 10.375,107.125, NE of the port on the open east side
     of the Vung Tau peninsula, off the ferry's route. Use **10.292,
     107.042** (first open-water cell SSW, on the route) instead. Con Dao
     island does not exist in the model (every cell around Bến Đầm is sea),
     so use **8.792,106.625**, about 10 km N on the straight-line approach.
     Both cells checked on a map and approved by Michael (2026-10-18). The
     ferry docks on Con Dao's SW side, but the score is meant to reflect
     open-sea conditions; the last minutes of sheltered docking don't
     matter.
  2. **Missing-data guard.** Treat null forecast values as unknown, not 0
     (calm); rate a departure "no data" if too many points are unknown.
     Log missing counts per run. (No nulls observed on 2026-10-18; this is
     a safeguard against false GREENs.)
  3. **Per-point detail in `state.json`:** each departure gets its 7
     points' scores and the component contributions (swell, resonance and
     beam multipliers, wind waves, secondary swell, wind) for the app's
     drill-down.
  4. **Roll-resonance band from real dimensions:** Thăng Long is 77.46 m
     long, 9.5 m beam (one source says 11.1 m), 2.2 m draft, a slender
     monohull (L/B ≈ 8). Its metacentric height (GM) isn't public, so the
     IMO roll-period estimate T ≈ 8.3/√GM s gives roughly 5–8.5 s for
     plausible GM of 1–3 m. Narrow `RESONANCE_PERIOD_RANGE` from the guessed
     6–11 s accordingly; still a heuristic until calibrated (design doc §7).
  5. Design doc: note the ~9 km resolution limit (harbors, bays and Con Dao
     island are invisible to the wave model).
- **Later idea: encounter period.** Roll resonance depends on the period at
  which waves reach the ship, which at ~32 kn differs a lot from the wave
  period (following seas arrive slower, head seas faster). Parked by
  Michael on 2026-10-18.
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
