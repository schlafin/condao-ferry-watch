"""Entry point -- run every 6 hours by .github/workflows/ferry-check.yml.

For every departure in the next config.LOOKAHEAD_DAYS, scores the worst
of the 7 waypoints (each at its own ETA hour), classifies it, and writes
state.json at the repo root. The workflow commits that file back so the
Mac app can fetch it from raw.githubusercontent.com.

The backend decides what is notification-worthy: rating changes go into
state.json's "events" list, each with a unique id. The Mac app only posts
events it hasn't seen before -- it never compares ratings itself.

Usage:
    python backend/main.py               # normal run
    python backend/main.py --test-event  # also add one synthetic event,
                                         # to test the notification path
"""

import json
import sys
from datetime import datetime, time, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

import config
import ferry_model
import fetch_openmeteo

STATE_PATH = Path(__file__).resolve().parent.parent / "state.json"
TZ = ZoneInfo(config.TIMEZONE)


def load_previous_ratings():
    if not STATE_PATH.exists():
        return {}
    with open(STATE_PATH) as f:
        state = json.load(f)
    return {d["id"]: d["rating"] for d in state.get("departures", [])}


def upcoming_departures(today):
    """Expand the active schedule into (leg, aware datetime) pairs."""
    sched = config.SCHEDULES[config.SCHEDULE_MODE]
    out = []
    for offset in range(config.LOOKAHEAD_DAYS):
        d = today + timedelta(days=offset)
        for leg, rule in sched.items():
            if d.weekday() in rule["weekdays"]:
                hh, mm = map(int, rule["depart_local"].split(":"))
                out.append((leg, datetime.combine(d, time(hh, mm), tzinfo=TZ)))
    return sorted(out, key=lambda x: x[1])


_forecast_cache = {}


def forecast_at(lat, lon):
    """Both legs use the same 7 points, so fetch each point only once."""
    key = (round(lat, 4), round(lon, 4))
    if key not in _forecast_cache:
        _forecast_cache[key] = (
            fetch_openmeteo.get_marine(lat, lon, timezone=config.TIMEZONE),
            fetch_openmeteo.get_wind(lat, lon, timezone=config.TIMEZONE),
        )
    return _forecast_cache[key]


def score_departure(leg, depart_dt):
    """Returns (worst score, index of worst waypoint), or (None, None) if
    the crossing falls outside the forecast range."""
    origin, destination = (
        (config.CAU_DA_PORT, config.BEN_DAM_PORT) if leg == "VT_TO_CD"
        else (config.BEN_DAM_PORT, config.CAU_DA_PORT)
    )
    waypoints = ferry_model.build_waypoints(origin, destination)
    route_bearing = ferry_model.bearing(origin, destination)
    n = len(waypoints)

    worst_score, worst_index = None, None
    for i, (lat, lon) in enumerate(waypoints):
        eta = ferry_model.eta_for_waypoint(depart_dt, i, n)
        # Open-Meteo is hourly: round the ETA to the nearest hour.
        eta_hour = (eta + timedelta(minutes=30)).replace(minute=0, second=0, microsecond=0)
        marine, wind = forecast_at(lat, lon)
        try:
            hour_index = marine["time"].index(eta_hour.strftime("%Y-%m-%dT%H:00"))
        except ValueError:
            return None, None  # beyond the forecast horizon
        seg = ferry_model.score_segment(marine, wind, hour_index, route_bearing)
        if worst_score is None or seg > worst_score:
            worst_score, worst_index = seg, i
    return worst_score, worst_index


def in_closure_window(d):
    start, end = config.TYPICAL_CLOSURE_MONTHS
    return d.month >= start or d.month <= end


def event_body(dep):
    when = datetime.fromisoformat(dep["depart"]).strftime("%a %d %b, %H:%M")
    body = f"{when} -- score {dep['score']:.2f} (was {dep['previous_rating'] or 'unrated'})"
    if dep["in_closure_window"]:
        body += (
            "\n⚠️ Falls within the ferry's typical seasonal closure window -- "
            f"verify the route is running at {config.ROUTE_STATUS_CHECK_URL} before booking."
        )
    return body


def main(test_event=False):
    now = datetime.now(TZ)
    generated_at = now.isoformat(timespec="seconds")
    previous = load_previous_ratings()

    departures, events = [], []
    for leg, depart_dt in upcoming_departures(now.date()):
        if depart_dt < now:
            continue
        score, worst_i = score_departure(leg, depart_dt)
        if score is None:
            continue
        dep_id = f"{leg}_{depart_dt.strftime('%Y-%m-%dT%H:%M')}"
        rating = ferry_model.classify(score)
        dep = {
            "id": dep_id,
            "leg": leg,
            "label": config.LEG_LABELS[leg],
            "depart": depart_dt.isoformat(),
            "score": round(score, 2),
            "rating": rating,
            "previous_rating": previous.get(dep_id),
            "worst_waypoint": worst_i,
            "in_closure_window": in_closure_window(depart_dt.date()),
        }
        departures.append(dep)

        # Notify on a change. A departure rated for the first time only
        # counts if it isn't RED -- otherwise every new day entering the
        # window during the monsoon season would fire a RED notification.
        prev = dep["previous_rating"]
        if rating != prev and not (prev is None and rating == "RED"):
            events.append({
                "id": f"{generated_at}|{dep_id}",
                "departure_id": dep_id,
                "title": f"{rating}: {dep['label']}",
                "body": event_body(dep),
            })

    if test_event:
        events.append({
            "id": f"{generated_at}|TEST",
            "departure_id": None,
            "title": "Test notification",
            "body": f"Pipeline test from the run at {generated_at}.",
        })

    state = {
        "generated_at": generated_at,
        "schedule_mode": config.SCHEDULE_MODE,
        "thresholds": {"green_max": config.GREEN_MAX, "yellow_max": config.YELLOW_MAX},
        "departures": departures,
        "events": events,
    }
    with open(STATE_PATH, "w") as f:
        json.dump(state, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"Wrote {STATE_PATH.name}: {len(departures)} departures, {len(events)} events")
    for d in departures:
        print(f"  {d['depart'][:16]}  {d['leg']}  {d['rating']:6}  {d['score']:.2f}")


if __name__ == "__main__":
    main(test_event="--test-event" in sys.argv)
