"""Send a macOS remote push notification via Apple Push Notification service.

Requires five GitHub Actions secrets (see macos-app/README-xcode-setup.md
for how to get each one):
  APNS_KEY_ID        - Key ID of your APNs Auth Key (.p8)
  APNS_TEAM_ID       - your Apple Developer Team ID
  APNS_AUTH_KEY      - full contents of the .p8 file (including
                       -----BEGIN/END PRIVATE KEY----- lines)
  APNS_DEVICE_TOKEN  - the token your Mac app prints on first launch
  APNS_BUNDLE_ID     - your app's bundle identifier (used as apns-topic)

Optional: APNS_ENV = "sandbox" (default) or "production".
A plain Xcode Debug build (Development signing) talks to the Apple Push
Notification service through the SANDBOX endpoint. Unless you later
package this as a signed, notarized Developer ID app with
aps-environment=production in its entitlements, leave this on sandbox --
sending to the production endpoint for a sandbox-registered token will
silently fail.
"""

import os
import time

import httpx
import jwt  # PyJWT with the [crypto] extra, for ES256

HOSTS = {
    "sandbox": "https://api.sandbox.push.apple.com",
    "production": "https://api.push.apple.com",
}


def _provider_token():
    key = os.environ["APNS_AUTH_KEY"]
    return jwt.encode(
        {"iss": os.environ["APNS_TEAM_ID"], "iat": int(time.time())},
        key,
        algorithm="ES256",
        headers={"kid": os.environ["APNS_KEY_ID"]},
    )


def send(title, body):
    token = os.environ.get("APNS_DEVICE_TOKEN")
    if not token:
        print(f"[no APNS_DEVICE_TOKEN set -- would have sent] {title}: {body}")
        return

    host = HOSTS[os.environ.get("APNS_ENV", "sandbox")]
    payload = {"aps": {"alert": {"title": title, "body": body}, "sound": "default"}}
    headers = {
        "authorization": f"bearer {_provider_token()}",
        "apns-topic": os.environ["APNS_BUNDLE_ID"],
        "apns-push-type": "alert",
    }
    with httpx.Client(http2=True) as client:
        resp = client.post(f"{host}/3/device/{token}", json=payload, headers=headers)
        if resp.status_code != 200:
            print(f"APNs error {resp.status_code}: {resp.text}")
        else:
            print(f"Sent: {title} -- {body}")
