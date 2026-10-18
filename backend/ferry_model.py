"""Route geometry and the smoothness scoring model.

The scoring is deliberately transparent and tunable from config.py rather
than a black box -- adjust the weights there as you learn more about how
this specific boat actually behaves.
"""

import math
from datetime import timedelta

import config


def interpolate_point(p1, p2, frac):
    """Linear interpolation between two (lat, lon) points. Fine at this
    scale (~100nm); no need for great-circle math."""
    lat = p1[0] + (p2[0] - p1[0]) * frac
    lon = p1[1] + (p2[1] - p1[1]) * frac
    return (lat, lon)


def bearing(p1, p2):
    """Initial bearing in degrees (0-360, 0=North) from p1 to p2."""
    lat1, lon1 = map(math.radians, p1)
    lat2, lon2 = map(math.radians, p2)
    dlon = lon2 - lon1
    x = math.sin(dlon) * math.cos(lat2)
    y = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dlon)
    return (math.degrees(math.atan2(x, y)) + 360) % 360


def angle_off_bow(route_bearing, wave_direction):
    """0 = wave arriving from dead ahead or dead astern (pitching only,
    which a long hull handles well). 90 = wave hitting broadside (beam
    seas -- the rolling condition that actually makes people seasick)."""
    diff = abs(route_bearing - wave_direction) % 360
    if diff > 180:
        diff = 360 - diff
    return 90 - abs(diff - 90)


def build_waypoints(origin, destination, n=config.NUM_WAYPOINTS):
    return [interpolate_point(origin, destination, i / (n - 1)) for i in range(n)]


def eta_for_waypoint(depart_dt, index, n, crossing_hours=config.CROSSING_HOURS):
    frac = index / (n - 1)
    return depart_dt + timedelta(hours=crossing_hours * frac)


SCORE_INPUTS = {
    # name in the result: (which forecast, Open-Meteo variable)
    "swell_m": ("marine", "swell_wave_height"),
    "swell_period_s": ("marine", "swell_wave_period"),
    "swell_dir_deg": ("marine", "swell_wave_direction"),
    "wind_wave_m": ("marine", "wind_wave_height"),
    "secondary_swell_m": ("marine", "secondary_swell_wave_height"),
    "wind_kmh": ("wind", "wind_speed_10m"),
}


def score_segment(hourly_marine, hourly_wind, hour_index, route_bearing):
    """Combine wave/swell/wind data at one waypoint and hour into a single
    discomfort score. Higher = rougher. See config.py for thresholds.

    Returns (score, parts), where parts shows how much each component
    contributed. If any input is missing, returns (None, {"missing": [...]})
    -- a missing value is unknown, never treated as calm.
    """
    series = {"marine": hourly_marine, "wind": hourly_wind}
    values, missing = {}, []
    for name, (source, var) in SCORE_INPUTS.items():
        column = series[source].get(var) or []
        value = column[hour_index] if hour_index < len(column) else None
        if value is None:
            missing.append(var)
        values[name] = value
    if missing:
        return None, {"missing": missing}

    wind_kt = values["wind_kmh"] * 0.539957
    lo, hi = config.RESONANCE_PERIOD_RANGE
    resonance_x = config.RESONANCE_MULTIPLIER if lo <= values["swell_period_s"] <= hi else 1.0
    off_bow = angle_off_bow(route_bearing, values["swell_dir_deg"])
    beam_x = 1 + 0.5 * math.sin(math.radians(off_bow))

    contributions = {
        "swell": values["swell_m"] * resonance_x * beam_x,
        "wind_waves": values["wind_wave_m"] * config.WIND_WAVE_WEIGHT,
        "secondary_swell": values["secondary_swell_m"] * config.SECONDARY_SWELL_WEIGHT,
        "wind": wind_kt / config.WIND_SPEED_DIVISOR_KT,
    }
    score = sum(contributions.values())
    parts = {
        "contributions": {k: round(v, 3) for k, v in contributions.items()},
        "inputs": {
            "swell_m": values["swell_m"],
            "swell_period_s": values["swell_period_s"],
            "swell_off_bow_deg": round(off_bow),
            "wind_wave_m": values["wind_wave_m"],
            "secondary_swell_m": values["secondary_swell_m"],
            "wind_kt": round(wind_kt, 1),
        },
        "resonance_x": resonance_x,
        "beam_x": round(beam_x, 3),
    }
    return score, parts


def classify(score):
    if score < config.GREEN_MAX:
        return "GREEN"
    if score < config.YELLOW_MAX:
        return "YELLOW"
    return "RED"
