"""Thin wrappers around Open-Meteo's free, keyless marine + weather APIs.

Chosen over Windy deliberately: Windy's production Point Forecast API is
EUR 990/year and their free tier only returns randomized test data, so it
isn't usable for a real automated pull. Open-Meteo gives the same class of
variables (wave/swell/wind-wave height, period, direction, secondary
swell) for free, with no API key, at hourly resolution.
"""

import time

import requests

MARINE_URL = "https://marine-api.open-meteo.com/v1/marine"
WEATHER_URL = "https://api.open-meteo.com/v1/forecast"

MARINE_VARS = [
    "wave_height", "wave_direction", "wave_period",
    "wind_wave_height", "wind_wave_direction", "wind_wave_period",
    "swell_wave_height", "swell_wave_direction", "swell_wave_period",
    "secondary_swell_wave_height", "secondary_swell_wave_direction", "secondary_swell_wave_period",
]

WIND_VARS = ["wind_speed_10m", "wind_gusts_10m", "wind_direction_10m"]

# Waits between attempts: try, wait 30s, try, wait 2 min, try, wait 5 min,
# try, then give up. Open-Meteo's marine server has had outages lasting
# minutes, so the waits are long enough to ride one out. Worst case for
# one request is 4 x 30s timeouts + 7.5 min of waiting, about 9.5 min.
RETRY_WAITS = [30, 120, 300]
REQUEST_TIMEOUT = 30  # seconds to wait for a response before retrying


def _get_hourly(url, params):
    """GET an Open-Meteo endpoint and return its "hourly" block, retrying
    timeouts, connection errors and 5xx responses. If the last attempt
    also fails, the error is raised so the run fails and the previous
    state.json is left untouched."""
    for attempt, wait in enumerate(RETRY_WAITS + [None], start=1):
        try:
            r = requests.get(url, params=params, timeout=REQUEST_TIMEOUT)
            if r.status_code < 500:
                r.raise_for_status()  # 4xx is our bug, not worth retrying
                return r.json()["hourly"]
            error = requests.HTTPError(f"{r.status_code} Server Error for {url}", response=r)
        except (requests.Timeout, requests.ConnectionError) as e:
            error = e
        if wait is None:
            raise error
        print(f"Open-Meteo attempt {attempt} failed ({error}); retrying in {wait}s")
        time.sleep(wait)


def get_marine(lat, lon, forecast_days=8, timezone="Asia/Ho_Chi_Minh"):
    params = {
        "latitude": lat, "longitude": lon,
        "hourly": ",".join(MARINE_VARS),
        "forecast_days": forecast_days,
        "timezone": timezone,
    }
    return _get_hourly(MARINE_URL, params)


def get_wind(lat, lon, forecast_days=8, timezone="Asia/Ho_Chi_Minh"):
    params = {
        "latitude": lat, "longitude": lon,
        "hourly": ",".join(WIND_VARS),
        "forecast_days": forecast_days,
        "timezone": timezone,
    }
    return _get_hourly(WEATHER_URL, params)


def get_historical_marine(lat, lon, start_date, end_date, timezone="Asia/Ho_Chi_Minh"):
    """For calibration: pull past marine conditions for a known date to
    compare against a remembered ride. Open-Meteo's marine endpoint accepts
    start_date/end_date for this on the same URL."""
    params = {
        "latitude": lat, "longitude": lon,
        "hourly": ",".join(MARINE_VARS),
        "start_date": start_date,  # "YYYY-MM-DD"
        "end_date": end_date,
        "timezone": timezone,
    }
    return _get_hourly(MARINE_URL, params)
