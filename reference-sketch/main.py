"""Entry point -- run on a schedule via .github/workflows/ferry-check.yml.

For every ferry departure scheduled in the next config.LOOKAHEAD_DAYS,
pulls Open-Meteo marine + wind data at waypoints along the route, scores
the WORST segment (one rough patch ruins the whole crossing even if the
rest is glassy), and sends a push notification when a departure's
classification changes -- in particular when something newly turns GREEN.

State is persisted to state.json and committed back to the repo each run
(see the workflow's "Persist state" step) so re-runs don't re-notify for
conditions that haven't changed.
"""

import json
import os
from datetime import datetime, timedelta, date

import config
import ferry_model
import fetch_openmeteo
import apns_push

STATE_PATH = "state.json"


def load_state():
    if os.path.exists(STATE_PATH):
        with open(STATE_PATH) as f:
            return json.load(f)
    return {}


def save_state(state):
    with open(STATE_PATH, "w") as f:
        json.dump(state, f, indent=2, default=str)


def route_status_ok():
    stale_by = config.ROUTE_LAST_CHECKED + timedelta(days=config.ROUTE_CHECK_STALE_AFTER_DAYS)
    if date.today() > stale_by:
        apns_push.send(
            "Con Dao ferry watcher",
            f"Route status hasn't been confirmed since {config.ROUTE_LAST_CHECKED}. "
            f"Check taucaotocthanglong.com / condao.express and update config.py.",
        )
    return config.ROUTE_ACTIVE


def upcoming_departures():
    """Expand config.SCHEDULES[mode] into concrete datetimes within the
    lookahead window."""
    sched = config.SCHEDULES[config.SCHEDULE_MODE]
    out = []
    today = date.today()
    for offset in range(config.LOOKAHEAD_DAYS):
        d = today + timedelta(days=offset)
        weekday = d.weekday()
        for leg, rule in sched.items():
            if weekday in rule["weekdays"] and weekday not in rule.get("exclude", []):
                hh, mm = map(int, rule["depart_local"].split(":"))
                depart_dt = datetime.combine(d, datetime.min.time()).replace(hour=hh, minute=mm)
                out.append((leg, depart_dt))
    return out


def score_departure(leg, depart_dt):
    origin, destination = (
        (config.CAU_DA_PORT, config.BEN_DAM_PORT) if leg == "VT_TO_CD"
        else (config.BEN_DAM_PORT, config.CAU_DA_PORT)
    )
    waypoints = ferry_model.build_waypoints(origin, destination)
    route_bearing = ferry_model.bearing(origin, destination)
    n = len(waypoints)

    worst_score = 0.0
    for i, (lat, lon) in enumerate(waypoints):
        eta = ferry_model.eta_for_waypoint(depart_dt, i, n)
        marine = fetch_openmeteo.get_marine(lat, lon)
        wind = fetch_openmeteo.get_wind(lat, lon)
        try:
            hour_index = marine["time"].index(eta.strftime("%Y-%m-%dT%H:00"))
        except ValueError:
            continue  # ETA fell outside the returned forecast window
        seg_score = ferry_model.score_segment(marine, wind, hour_index, route_bearing)
        worst_score = max(worst_score, seg_score)

    return worst_score


def main():
    if not route_status_ok():
        print("Route marked inactive in config.py -- skipping forecast checks.")
        return

    state = load_state()
    new_state = {}

    for leg, depart_dt in upcoming_departures():
        key = f"{leg}_{depart_dt.isoformat()}"
        score = score_departure(leg, depart_dt)
        classification = ferry_model.classify(score)
        new_state[key] = {"score": round(score, 2), "classification": classification}

        previous = state.get(key, {}).get("classification")
        if classification != previous:
            direction = "Vung Tau -> Con Dao" if leg == "VT_TO_CD" else "Con Dao -> Vung Tau"
            apns_push.send(
                f"{classification}: {direction}",
                f"{depart_dt.strftime('%a %b %d, %H:%M')} -- score {score:.2f} "
                f"(was {previous or 'unrated'})",
            )

    save_state(new_state)


if __name__ == "__main__":
    main()
