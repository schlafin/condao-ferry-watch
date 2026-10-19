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
    That retry window (~1.5 min) wasn't enough on 2026-10-18/19: three
    scheduled runs in a row failed over ~10 h. Candidate follow-up: longer
    waits and timeout.
  - **raw.githubusercontent.com cache bug (found 2026-10-19):** its CDN
    served a stale *compressed* copy of `state.json` 18 h after a newer
    commit (despite `max-age=300`), while uncompressed requests were
    fresh. The app now adds `?t=<unix time>` to every fetch to bypass the
    cache. Keep that; don't "simplify" it away.
- **Direction (2026-10-18): go as far as possible on the free tier first.**
  APNs ($99) is deferred until Michael decides he needs alerts while the
  app is closed. Planned free-tier PRs, in order D → A → B → C:
  - **PR A, real Mac app (in progress on branch `window-app`):** normal
    window app installed in Applications (Archive → Copy App). Built and
    tested 2026-10-18: main window, Settings window (⌘,), and a "Show in
    menu bar" setting (off by default). On = closing the main window keeps
    the app running as a menu bar extra and offers Launch at login; off =
    closing the main window quits. Nothing runs invisibly. One copy at a
    time.
    **Display redesign (agreed 2026-10-19).** Michael's rule: as little
    clutter as possible, few words, few numbers; the layout itself should
    carry the meaning.
    - **Color = smooth gradient on the score, 0 green → ~1 yellow → 2+ red**
      (clamped at 2), gray for missing data. Fixed scale on purpose:
      Michael will learn what each shade feels like on the ferry rather
      than calibrating thresholds. The GREEN/YELLOW/RED limits no longer
      drive the display.
    - Main window rows: a **calendar square** instead of the dot (full
      weekday name in the top band, large day number, departure time with
      AM/PM underneath, e.g. "7:30 AM"). Blue body with the number and
      time in white (blue isn't in the gradient, so every shade stands
      out); the top band with the weekday takes the worst point's
      gradient color. Times are always Vietnam time, with no label. Below the route name, a **path bar** running to the row's
      right edge, a smooth blend of the 7 points' gradient colors.
      Removed: date/time text, score number, ▸ arrow (the whole row
      expands it).
    - Grouping: the Vung Tau → Con Dao departures, a gap, then Con Dao →
      Vung Tau. No group labels. Title "Upcoming Departures" stays.
      Removed: the "Forecast run…" line and the ⚠️. The closure note stays,
      with the refresh time under it.
    - **Menu bar panel = calendar strip** (replaces the earlier
      weekday-chip idea): two rows, one per direction, with one column per
      day, so return dates sit between outbound dates and a trip reads at
      a glance:
      ```
      Vung Tau → Con Dao    20      22      24
      Con Dao → Vung Tau        21      23
      ```
      Day numbers are drawn in their worst-point gradient color as plain
      text (designed for dark mode). Clicking anywhere opens the main
      window; a small ✕ at the top right quits the app (same as the old
      Quit button).
    - The drill-down stays as is in this PR; Michael will redo its
      content in a separate PR.
    - **Notifications:** the backend stops writing rating-change events,
      but the plumbing stays: the app can still show notifications, and
      the workflow's `test_event` still works, so a future score-change
      PR only has to decide when to notify. Menu-bar mode stays; its
      Settings wording changes to "keeps the menu bar panel current"
      instead of mentioning notifications.
  - **PR B, desktop widget** (WidgetKit) with a Refresh button and no
    automatic refresh.
  - Optional PR C: Shortcuts/Siri action (App Intents).
- **PR D, merged (PR #4, 2026-10-18)** (backend only):
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
- **Removed after review (2026-10-19): rating-change notifications.**
  Notifying when a departure moved between GREEN/YELLOW/RED was judged
  ineffective: borderline scores flip categories on small variations and
  fire notifications for meaningless changes.
- **Removed after review: the "was YELLOW" badge.** A single previous value
  isn't informative enough.
- **Future PR: score-change notifications.** Notify when a departure's
  score changes by more than a meaningful amount (e.g. 0.3) instead of on
  category flips.
- **Future PR: forecast deltas over time.** Whether a departure's forecast
  is getting better or worse across runs matters for trip planning. Needs
  proper design (history of scores per departure, how to show the trend).
- **PR E: "soft notification" menu bar icon** (agreed 2026-10-19, after
  PR A). Only meaningful in menu-bar mode, since the app must be running.
  - The icon switches from waves to waves-with-"!" when a departure's
    **worst-point** score is below a threshold (e.g. 0.4) set in the
    **Settings window**. Stays monochrome per Apple's guidance; at most a
    one-time pulse when it appears (test first whether symbol animation
    works in the menu bar at all).
  - The "!" clears once seen (panel or main window opened), like a read
    mark, and only returns for a newly qualifying departure.
  - Direction comes from **your location**: if Vung Tau is the nearer
    port, it watches Vung Tau → Con Dao; if Con Dao is nearer, Con Dao →
    Vung Tau. Needs Core Location, the sandbox location entitlement, a
    usage-description string, and a one-time permission prompt; the
    coarsest accuracy is enough. Fallback if location is denied: a "Home
    port" picker in Settings.
  - Everything stays "worst point" for now; an average-based option may
    come after real-world testing.
- **Future PR: light/dark mode color schemes.** Colors are currently
  designed for dark mode only (Michael's setting); the gradient text
  colors need a light-mode variant.
- **Future PR: drill-down redesign** (Michael's own design). Includes the
  ETA display fix: points currently show the rounded forecast hour (07:30
  departure → "08:00" for both Start and Point 1); show the actual ETA
  (07:30, 08:05, 08:40, …) with the forecast hour it used. Needs the
  backend to publish the real ETA too.
- **Later idea: encounter period.** Roll resonance depends on the period at
  which waves reach the ship, which at ~32 kn differs a lot from the wave
  period (following seas arrive slower, head seas faster). Parked by
  Michael on 2026-10-18.
- The GitHub CLI login now has the `workflow` scope (needed to push files
  under `.github/workflows/`).
- The old untested `reference-sketch/` v1 draft was deleted on 2026-10-18,
  superseded by `backend/` and `ConDaoFerryWatch/`. It's still in git
  history (`git show b03065b:reference-sketch/...`) if ever needed.
- Workflow uses `actions/checkout@v7` and `actions/setup-python@v7` (Node
  24); the v4/v5 versions triggered Node 20 deprecation warnings.

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
