#!/usr/bin/env bash
# LocalShare launcher.
#  - Linux with NetworkManager: creates a Wi-Fi hotspot, then starts the server.
#  - Termux (Android), or any system with -n: no hotspot is created. Turn on
#    your hotspot yourself (or join the same Wi-Fi), and the server starts.
# Usage: ./start.sh [-i interface] [-s ssid] [-p password] [-n]

cd "$(dirname "$0")" || exit 1

IFACE=""
SSID="LocalShare"
PASS="localshare123"
PORT=3000
NO_HOTSPOT=0
IS_TERMUX=0

# Detect Termux
if [ -n "$TERMUX_VERSION" ] || [[ "$PREFIX" == *com.termux* ]]; then
  IS_TERMUX=1
  NO_HOTSPOT=1
fi

while getopts "i:s:p:n" opt; do
  case $opt in
    i) IFACE="$OPTARG" ;;
    s) SSID="$OPTARG" ;;
    p) PASS="$OPTARG" ;;
    n) NO_HOTSPOT=1 ;;
    *) echo "Usage: $0 [-i interface] [-s ssid] [-p password] [-n]"; exit 1 ;;
  esac
done

if [ "$NO_HOTSPOT" -eq 0 ] && [ ${#PASS} -lt 8 ]; then
  echo "Wi-Fi password must be at least 8 characters."
  exit 1
fi

# ---------- Check requirements ----------
REQUIRED="node npm"
[ "$NO_HOTSPOT" -eq 0 ] && REQUIRED="$REQUIRED nmcli"
for cmd in $REQUIRED; do
  command -v "$cmd" >/dev/null || { echo "Missing '$cmd'. Please install it first."; exit 1; }
done

# Auto-detect the Wi-Fi interface (hotspot mode only)
if [ "$NO_HOTSPOT" -eq 0 ] && [ -z "$IFACE" ]; then
  IFACE=$(nmcli -t -f DEVICE,TYPE device | awk -F: '$2=="wifi"{print $1; exit}')
  if [ -z "$IFACE" ]; then
    echo "No Wi-Fi interface found. Use -i to set one (see 'nmcli device')."
    exit 1
  fi
fi

# Install dependencies on the first run
if [ ! -d node_modules ]; then
  echo "Installing dependencies..."
  npm install || { echo "npm install failed."; exit 1; }
fi

# Check the server code for errors BEFORE touching the network
if ! node --check server.js; then
  echo "server.js has an error (shown above). Fix it and try again."
  exit 1
fi

# Make sure the port is free
if command -v ss >/dev/null && ss -ltn 2>/dev/null | grep -q ":$PORT "; then
  echo "Port $PORT is already in use by another program."
  echo "If it is an old LocalShare server, stop it first (for example: pkill -f 'node server.js')."
  exit 1
fi

# ---------- Cleanup on exit ----------
HOTSPOT_CON=""

cleanup() {
  echo
  if [ -n "$HOTSPOT_CON" ]; then
    echo "Stopping hotspot..."
    sudo nmcli connection delete id "$HOTSPOT_CON" >/dev/null 2>&1 || true
  fi
  if [ "$IS_TERMUX" -eq 1 ] && command -v termux-wake-unlock >/dev/null; then
    termux-wake-unlock
  fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# ---------- Network setup ----------
if [ "$NO_HOTSPOT" -eq 0 ]; then
  echo "Starting hotspot '$SSID' on $IFACE..."
  if ! sudo nmcli device wifi hotspot ifname "$IFACE" ssid "$SSID" password "$PASS"; then
    echo "Could not start the hotspot. Check that your Wi-Fi card supports AP mode:"
    echo "  iw list | grep -A 10 'Supported interface modes'"
    exit 1
  fi

  # Find the name NetworkManager gave it (Hotspot, Hotspot-1, ...)
  HOTSPOT_CON=$(nmcli -t -f NAME,DEVICE connection show --active | awk -F: -v dev="$IFACE" '$2==dev {print $1; exit}')
  echo "Hotspot connection: ${HOTSPOT_CON:-unknown}"

  echo
  echo "Join the Wi-Fi: $SSID  (password: $PASS)"
  if command -v qrencode >/dev/null; then
    qrencode -t ansiutf8 "WIFI:T:WPA;S:$SSID;P:$PASS;;"
  fi
else
  echo "No-hotspot mode: this script will NOT create a Wi-Fi hotspot."
  echo "Turn on your hotspot (or connect to the same Wi-Fi/router) yourself."
  if [ "$IS_TERMUX" -eq 1 ]; then
    # Keep the phone from sleeping and killing the server
    command -v termux-wake-lock >/dev/null && termux-wake-lock
    echo
    echo "On this phone, open:  http://localhost:$PORT"
    echo "Other devices: join this phone's hotspot and open http://<hotspot IP>:$PORT"
    echo "(the hotspot IP is often 192.168.43.1; see your hotspot settings)"
  fi
fi
echo

# ---------- Run the server ----------
node server.js
CODE=$?

echo
echo "Server stopped (exit code $CODE)."
exit $CODE
