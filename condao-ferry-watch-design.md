# Con Dao Ferry Watch — Design Document

**Repo:** https://github.com/schlafin/condao-ferry-watch
**Status:** Design complete, not yet implemented in the repo. A draft v1
sketch of the code (Python scoring engine, GitHub Actions workflow, Swift
app skeleton) was produced in an earlier chat session and exists as a
local zip — treat it as a reference sketch, not a locked spec. Rewrite or
restructure freely as long as the behavior below is preserved.

---

## 1. Goal

Michael wants a 4–5 day trip to Con Dao: leave Vung Tau by ferry in the
morning, 3 nights on the island, return by ferry — timed for the calmest
seas available, with enough lead time to book (he plans to book last-
minute: night-before or morning-of). The system should watch the specific
Vung Tau ⇄ Con Dao ferry crossing and push a notification to his Mac 2–3
days ahead when an upcoming scheduled departure looks smooth, then keep
updating that assessment as the date approaches.

This is a personal, single-user tool. Optimize for correctness and low
maintenance over generality.

Conditions should also be browsable inside the app at any time,
independent of whether a notification has fired — see §9.

## 2. Real-world constraints (read this before writing any scheduling logic)

**The route is seasonal and currently suspended.** The ferry — a single
vessel, "Thăng Long," operated by Phú Quốc Express — is pulled off this
route every year for the monsoon season. Observed pattern from the last
three years:

| Season | Suspended | Resumed |
|---|---|---|
| 2024 | Sep 14, 2024 | Feb 7, 2025 |
| 2025 | Sep 3, 2025 | Feb 26, 2026 |
| 2026 | **Aug 1, 2026** | not yet announced |

As of this writing (Sep 2026) the route has been down since Aug 1 with no
confirmed restart date. **There is no reliable API for "is the route
running," and the system deliberately does not try to auto-detect it.**

**Design decision: no active/inactive gate in the code, and no automated
live status check.** The app always computes conditions and always
attempts to notify — there's no config flag or precondition that skips a
run. Weather-based scoring already suppresses most false "go" signals
during the real shutdown period on its own, since the conditions that
make the operator suspend service usually also score RED. Two related
decisions, both made deliberately rather than left as defaults:

- **No automated scrape of the ferry's booking/status site.** Considered
  triggering a live check of taucaotocthanglong.com only when a score
  crosses GREEN (cheap to trigger — it's rare, and a single fetch is
  nearly free either way). Rejected: the cost was never compute, it's
  reliability. Small operator ticketing sites are often JS-rendered
  booking widgets rather than static pages with a stable "suspended"
  banner in the raw HTML, so a scraper built against today's layout can
  silently start returning false "looks open" results the day the site
  changes — and a false negative here is worse than no check at all,
  since it actively encourages booking on bad information. Instead,
  every notification just includes the check-URL as a plain link, and
  Michael verifies manually the rare times this actually fires.
- **On/off control lives at the OS level, not in this codebase.** No
  workflow-disable step, no config flag. Michael controls whether he
  actually *sees* notifications via macOS System Settings → Notifications
  → ConDaoFerryWatch — muted during the known shutdown window, re-enabled
  as the historical reopening window approaches. Note the distinction
  between fully disabling "Allow Notifications" (suppresses delivery
  entirely, nothing recorded) versus setting the alert style to "None"
  while leaving delivery on (notifications still land silently in
  Notification Center, giving a browsable history of what fired while
  muted) — the latter is almost certainly what he'll actually want.
- **Config still carries a `TYPICAL_CLOSURE_WINDOW`** (approximate, based
  on the three-year pattern in the table above — currently roughly Aug
  through Feb) and a `ROUTE_STATUS_CHECK_URL` (taucaotocthanglong.com,
  with condao.express as a mirror). Any notification for a departure
  whose date falls inside that window gets an appended line, e.g.:
  *"⚠️ Falls within the ferry's typical seasonal closure window (exact
  dates vary year to year) — verify the route is actually running at
  <URL> before booking."* This keeps the system honest about what it
  doesn't know, without claiming a live status it has no source for.

**Schedule, when running:**
- Standard (year-round baseline): Vũng Tàu → Côn Đảo departs 07:30,
  Tue/Thu/Sat. Côn Đảo → Vũng Tàu departs 13:00, Wed/Fri/Sun. No Monday
  sailings.
- Peak season (documented mid-Apr–mid-Jun 2026, informally extended
  through summer weekends in past years): daily except Monday, same
  departure times.
- Crossing time ~3.5 hours, ~97nm / 185km, cruising ~32 knots.

This should be config-driven (a "standard" vs "peak" schedule mode),
updated by hand when the operator changes it — not auto-detected.

**Best-odds months, if/when the route is running:** roughly March–June.
The operator's own site flags July–August as rougher even within the
operating season, and the annual shutdown already excludes the worst of
it (Aug/Sep–Feb). This also happens to be the easiest booking window —
avoids Tết and the worst summer-weekend crowding, so the calm-sea window
and the easy-to-book window largely coincide. Seat availability itself
(sold out or not) is **not** part of this system's scope — a 1,000+ seat
boat makes day-before booking realistic outside major holidays, and
availability isn't reliably automatable (no stable API; the booking
sites are fragile to scrape). Treat that as a manual check via the
operator's Zalo hotline once a smooth window is identified.

## 3. Why Open-Meteo, not Windy

Windy's map is the best visualization for eyeballing conditions by hand,
but it is **not viable as an automation backend**:
- The production Point Forecast API is €990/year.
- The free "testing" key returns randomized/modified data — explicitly
  not for production use.
- Windy is dot-based anyway (one point per query), which doesn't solve
  the "path, not a point" problem even if it were free.

**Open-Meteo's Marine Weather API** is the backend of choice: free,
keyless, hourly resolution, up to 16 days out, and has every variable
needed:
- `wave_height`, `wave_direction`, `wave_period`
- `wind_wave_height`, `wind_wave_direction`, `wind_wave_period`
- `swell_wave_height`, `swell_wave_direction`, `swell_wave_period`
- `secondary_swell_wave_height/direction/period` (for detecting confused
  seas — two swell trains from different directions)

Endpoint: `https://marine-api.open-meteo.com/v1/marine`

Combine with Open-Meteo's standard Forecast API
(`https://api.open-meteo.com/v1/forecast`) for `wind_speed_10m`,
`wind_gusts_10m`, `wind_direction_10m` at the same coordinates.

Both also support `start_date`/`end_date` for **historical** data —
useful for calibration (see §7).

Stormglass is a plausible second source but its free tier is capped at
10 requests/day, which won't cover a multi-waypoint path query run twice
daily. Not worth building around unless Open-Meteo's coverage proves
inadequate.

## 4. Route/path model

Windy (and most consumer marine forecasts) give you a single point. The
actual crossing has ~100nm of open water where conditions can vary
meaningfully from one end to the other. The model:

1. Define the two ports:
   - Cầu Đá Port, Vũng Tàu: **(10.3360, 107.0850)** (approximate — verify
     against a map before relying on precision)
   - Bến Đầm Port, Côn Đảo: **(8.6975, 106.6017)** (approximate)
2. Interpolate **7 evenly-spaced waypoints** along the straight line
   between them (linear interpolation is fine at this scale — great-
   circle vs. rhumb-line difference over 97nm is negligible).
3. For a given scheduled departure time, compute each waypoint's
   **estimated time of arrival** based on constant-speed progress
   (crossing_hours × fraction-of-route), and query the forecast for
   *that specific hour* at that point — not "now" for every waypoint.
   This is what makes it a path model instead of one point sampled
   seven times.
4. Compute the initial bearing of the route (for angle-of-attack
   scoring, §5).

## 5. Scoring model

Wave height alone is a poor predictor of ride comfort. What actually
matters, in rough order of importance for a large vessel:

- **Significant/swell wave height** — baseline magnitude.
- **Swell period** — long-period swell can resonate with a vessel's roll
  more than short wind-chop of the same height. We don't have Thăng
  Long's actual roll-resonance period; treat any period-based penalty as
  a heuristic pending calibration (§7), not fact.
- **Angle between swell direction and the ship's heading** — beam seas
  (swell hitting roughly broadside, ~90° off the bow) cause rolling,
  which is what actually makes people seasick. Head or following seas
  cause pitching, which a long hull handles much better. The same wave
  height can be a non-event or miserable purely depending on this angle.
  This is the detail most manual weather-checking (including Michael's
  past Windy use) misses entirely.
- **Secondary swell** — a second swell train from a different direction
  creates a "confused sea," often worse-feeling than either component
  alone.
- **Wind-wave height** (local wind-driven chop) and **wind speed/gusts**
  — secondary contributors.

Suggested formula (starting point, tune via §7):

```
score = swell_height
score *= RESONANCE_MULTIPLIER if swell_period in RESONANCE_RANGE_SECONDS else 1.0
score *= (1 + 0.5 * sin(angle_off_bow_degrees_in_radians))
score += wind_wave_height * WIND_WAVE_WEIGHT
score += secondary_swell_height * SECONDARY_SWELL_WEIGHT
score += wind_speed_knots / WIND_SPEED_DIVISOR
```

Where `angle_off_bow` maps 0° (head/following) → factor 1.0 and 90°
(beam) → factor 1.5.

**Aggregate per departure as the worst-scoring waypoint, not an
average.** One rough patch mid-crossing ruins the whole ride even if the
rest is glassy.

Classify into GREEN / YELLOW / RED via two threshold constants. **These
thresholds are unvalidated guesses** — see §7 before trusting them for
real trip planning.

## 6. Notification design

**Delivery mechanism:** Apple Push Notification service (APNs), sent
directly to a native macOS menu-bar app. Chosen over ntfy.sh/Telegram/
email specifically because Michael decided the $99/year Apple Developer
Program cost is worth it for a proper native-notification experience.

**Why this needs care:** APNs pushes are sent server-side (from the
GitHub Actions job) using provider authentication — there's no polling
involved and no dependency on the Mac being awake to *check* anything,
only to have registered once. Requirements:

- An **APNs Auth Key** (.p8 file) from the Apple Developer portal —
  provides `APNS_KEY_ID` and pairs with the account's `APNS_TEAM_ID`.
- The macOS app requests notification permission
  (`UNUserNotificationCenter`) and registers for remote notifications
  (`NSApplication.registerForRemoteNotifications()`), which yields a
  **device token** — printed to console on first run, then hand-copied
  into a GitHub secret. There is no dynamic device-registration server;
  for a single-user tool, one manual copy-paste is simpler than building
  one.
- **Sandbox vs. production environment matters and is a common failure
  point.** A plain Xcode Debug build (development signing) registers
  against APNs' **sandbox** endpoint (`api.sandbox.push.apple.com`).
  Sending to the production endpoint for a sandbox-registered token
  silently fails. Default to sandbox; this works indefinitely for
  personal use without needing Developer ID signing or notarization.
  Only move to production if the app is later archived/distributed as a
  signed release build (and its entitlements' `aps-environment` updated
  to match).
- JWT provider token: ES256-signed, header `{"alg":"ES256","kid":
  APNS_KEY_ID}`, payload `{"iss": APNS_TEAM_ID, "iat": <unix ts>}`.
  PyJWT with the `[crypto]` extra handles this.
- POST to `https://api.sandbox.push.apple.com/3/device/<device_token>`
  with `apns-topic: <bundle_id>`, `apns-push-type: alert`, and a JSON
  body `{"aps": {"alert": {"title": ..., "body": ...}, "sound":
  "default"}}`. Requires an HTTP/2-capable client (e.g. Python's `httpx`
  with `http2=True`).

**GitHub secrets needed:** `APNS_KEY_ID`, `APNS_TEAM_ID`,
`APNS_AUTH_KEY` (full .p8 contents), `APNS_DEVICE_TOKEN`,
`APNS_BUNDLE_ID`.

**Notification trigger logic:** persist a `state.json` of the last-known
classification per scheduled departure (keyed by leg + departure
datetime). On each run, only notify when a departure's classification
*changes* — this avoids re-notifying at every run for conditions that
haven't moved, while still surfacing both improvements (YELLOW→GREEN)
and degradations (GREEN→YELLOW/RED) as the date approaches. Since GitHub
Actions runs are stateless/ephemeral, `state.json` needs to be committed
back to the repo at the end of each run (requires `permissions:
contents: write` in the workflow and a git commit/push step).

## 7. Calibration — turn guesses into evidence

Two numbers in this system are currently unvalidated:
- The GREEN/YELLOW/RED score thresholds
- The "resonance risk" swell-period band used in the scoring formula

Michael has personally ridden this ferry at least twice: once in calm
conditions, once in rough/choppy conditions. If he can recall roughly
which dates those were, Open-Meteo's marine endpoint supports
`start_date`/`end_date` historical queries at the same coordinates used
above. Pulling the actual recorded swell height/period/direction and
wind data for those two known crossings would let the thresholds be set
from his own lived experience rather than arbitrary starting guesses —
worth doing before relying on this for real trip planning. This should
be a small standalone script/notebook, not part of the production
pipeline.

## 8. Scheduling (GitHub Actions)

- **Cron: every 6 hours** (`0 23,5,11,17 * * *` UTC = 00:00, 06:00,
  12:00, 18:00 ICT), plus `workflow_dispatch` for manual test runs.
  Reasoning for the interval: the underlying wave/wind models Open-Meteo
  draws from refresh on a ~6-hour cycle, so polling more often than that
  (e.g. hourly) mostly re-fetches the same model run rather than new
  information — a 6-hour cadence tracks new data closely without wasted
  calls, and updates 4x/day, which is plenty for a decision made 2-3 days
  out.
- Every run recomputes and overwrites `state.json` with the latest
  snapshot for all departures in the lookahead window — this is
  unconditional, not gated on route status (see §2).
- Steps: checkout → set up Python → install deps (`requests`,
  `httpx[http2]`, `PyJWT[crypto]`) → run the main script with the five
  APNs secrets as env vars → commit `state.json` back to the repo.
- No route-active gate and no live status check (see §2) — the
  seasonal-closure caveat is just a date-range check applied when
  formatting a notification's message text. The job always runs, always
  scores, and always attempts to notify; muting happens at the OS level.

## 9. macOS app

Two responsibilities, not one:

1. **Notification registration** — request notification permission once,
   register for remote notifications, print the device token for the
   one-time copy into GitHub secrets. (As before.)
2. **Display current conditions on demand** — the menu-bar dropdown
   fetches the latest `state.json` from the repo whenever opened (and
   optionally on a timer while running, e.g. every 15-30 min) and lists
   upcoming scheduled departures with their color rating, so Michael can
   check conditions any time without waiting for a notification. This is
   new versus the original design: since the conditions-engine now always
   runs regardless of notification status (§2), the app needs its own
   read path rather than being a passive push receiver only.

All scoring/business logic still lives entirely in the GitHub Actions
job — the app only fetches and displays, never computes.

**Repo visibility: done.** Public as of now, so `state.json` can be
fetched via a plain `raw.githubusercontent.com/.../state.json` request
with no credentials embedded in the client.

Key implementation notes:
- `LSUIElement = true` in Info.plist to keep it menu-bar-only (no Dock
  icon).
- Entitlements: `com.apple.developer.aps-environment` = `development`
  (matches sandbox APNs, see §6), `com.apple.security.network.client` =
  true.
- If Xcode only offers the SwiftUI app lifecycle, wrap the delegate via
  `@NSApplicationDelegateAdaptor` rather than fighting for the older
  AppKit lifecycle template.

**iOS: deferred, not designed out.** Michael has decided to build
macOS-only for now and add iOS later. When that happens, the practical
path is a SwiftUI multiplatform target sharing this same data model and
fetch logic, with the iOS side built as a **WidgetKit** home-screen
widget rather than a full app screen — less to build, and closer to the
original "app or widget" framing than a navigable screen would be. Each
platform registers its own separate APNs device token (a phone and a Mac
are different devices), so the backend would need to store and loop over
a short list of tokens instead of one — a small addition to
`apns_push.py`, not a redesign. Nothing in the current design blocks
this later; no need to build toward it now.

## 10. Apple Developer setup checklist (one-time, manual)

1. Enroll in the Apple Developer Program ($99/yr) — Michael has approved
   this cost.
2. Create the Xcode project, note its Bundle Identifier.
3. Signing & Capabilities: select Team, add "Push Notifications"
   capability, optionally "Background Modes → Remote notifications."
4. Build/run once, capture the printed device token.
5. Developer portal → Keys → create an APNs Auth Key, download the .p8
   **immediately** (one-time download), note Key ID and Team ID.
6. Add all five secrets to the GitHub repo (Settings → Secrets and
   variables → Actions).
7. Trigger a manual `workflow_dispatch` run before waiting on the cron
   schedule, to confirm the whole chain works end to end.

## 11. Explicitly out of scope for v1

- Automated seat-availability/sold-out checking (fragile to scrape; do
  manually via the operator's booking channel once a smooth window is
  found).
- Automated route-active/season detection, and any automated live check
  of the ferry's status/booking site — deliberately not attempted; see
  §2 for why (reliability, not cost). Handled instead by a date-range
  caveat in notification text, plus Michael muting notifications via
  macOS System Settings around the season boundary.
- iOS app (deferred, not designed out — see §9's forward-compat note;
  the likely form later is a WidgetKit widget, not a full second app).
- Historical charting / trend view of past conditions — `state.json`
  holds only the latest snapshot, overwritten each run, not a running
  log. Possible future enhancement, not needed for the core "tell me
  when to book" workflow.
