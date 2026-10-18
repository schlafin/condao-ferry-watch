# Con Dao Ferry Watch

Watches the Vung Tau ⇄ Con Dao high-speed ferry route (Phu Quoc Express's
"Thang Long") for smooth-sea departure windows and pushes a native macOS
notification when one comes up, 2-3 days out, then updates as it approaches.

## How it works

1. **GitHub Actions** runs `main.py` twice a day, independent of your own
   machine's power/internet.
2. For each scheduled departure in the next 7 days, it samples 7 points
   along the actual sea route (not one dot), pulling free marine +
   wind forecasts from **Open-Meteo** (not Windy — see below) for the hour
   each waypoint would actually be crossed.
3. Each point gets a "discomfort" score from swell height, swell period
   (penalizing periods that risk resonance), how beam-on the swell is
   relative to the ship's heading, wind-wave chop, secondary swell
   (confused seas), and wind speed.
4. The **worst** point along the route sets the departure's rating
   (GREEN/YELLOW/RED) — one rough patch ruins the crossing even if the
   rest is calm.
5. When a departure's rating changes, it pushes a notification straight to
   your Mac via Apple Push Notification service (APNs) — no Windy, no
   ntfy, no Telegram bot needed.

## Before this is useful at all

**The route is currently suspended** (since Aug 1, 2026, no announced
restart). Phu Quoc Express pulls this specific ferry every year for the
monsoon season — check `config.py`'s `ROUTE_ACTIVE` flag and the notes
there before relying on this for trip planning. There's no way to
automate that check reliably, so it's a manual flag you flip a couple of
times a year.

## Why Open-Meteo instead of Windy

Windy's map is great to eyeball by hand, but its production API is
€990/year, and the free "testing" key returns randomized fake data — not
usable for real automated pulls. Open-Meteo's Marine Weather API is free,
keyless, and has the same class of variables (swell height/period/
direction, wind-wave data, secondary swell) at hourly resolution.

## Setup order

1. `pip install -r requirements.txt` locally if you want to test `main.py`
   directly before wiring up Actions.
2. Follow `macos-app/README-xcode-setup.md` to build the menu bar app,
   enroll in the Apple Developer Program, and get your APNs credentials.
3. Add the five secrets it lists to your GitHub repo.
4. Push the repo, enable Actions, and trigger a manual run to confirm the
   whole chain works before waiting for the twice-daily schedule.

## What's still a guess, not a fact

- **Scoring thresholds** (`GREEN_MAX`, `YELLOW_MAX` in `config.py`) are
  starting points, not calibrated against this specific boat.
- **Resonance period band** (6-11s) is a heuristic for a ~77m monohull,
  not Thang Long's actual roll characteristics.
- **Port coordinates** are approximate.

If you can give me the rough dates of your calm crossing and your choppy
crossing, `fetch_openmeteo.get_historical_marine()` can pull the actual
swell/wind data Open-Meteo recorded for those two days, and we can set
real thresholds instead of guesses — the same falsifiability instinct as
your valuation pipeline, just applied to wave height.
