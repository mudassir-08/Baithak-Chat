#!/usr/bin/env bash
# LocalShare launcher: creates a Wi-Fi hotspot and starts the server.
# Usage: ./start.sh [-i interface] [-s ssid] [-p password]

cd "$(dirname "$0")" || exit 1

IFACE=""
SSID="LocalShare"
PASS="localshare123"
PORT=3000

while getopts "i:s:p:" opt; do
  case $opt in
    i) IFACE="$OPTARG" ;;
    s) SSID="$OPTARG" ;;
    p) PASS="$OPTARG" ;;
    *) echo "Usage: $0 [-i interface] [-s ssid] [-p password]"; exit 1 ;;
  esac
done

if [ ${#PASS} -lt 8 ]; then
  echo "Wi-Fi password must be at least 8 characters."
  exit 1
fi

# ---------- Check requirements ----------
for cmd in node npm nmcli; do
  command -v "$cmd" >/dev/null || { echo "Missing '$cmd'. Please install it first."; exit 1; }
done

# Auto-detect the Wi-Fi interface if not given
if [ -z "$IFACE" ]; then
  IFACE=$(nmcli -t -f DEVICE,TYPE device | awk -F: '$2=="wifi"{print $1; exit}')
fi
if [ -z "$IFACE" ]; then
  echo "No Wi-Fi interface found. Use -i to set one (see 'nmcli device')."
  exit 1
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
if ss -ltn 2>/dev/null | grep -q ":$PORT "; then
  echo "Port $PORT is already in use by another program."
  echo "If it is an old LocalShare server, stop it with:"
  echo "  sudo pkill -f 'node server.js'"
  exit 1
fi

# ---------- Hotspot cleanup ----------
HOTSPOT_CON=""

cleanup() {
  echo
  echo "Stopping hotspot..."
  if [ -n "$HOTSPOT_CON" ]; then
    # Delete the exact connection that was created (Hotspot, Hotspot-1, ...)
    sudo nmcli connection delete id "$HOTSPOT_CON" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# ---------- Start the hotspot ----------
echo "Starting hotspot '$SSID' on $IFACE..."
if ! sudo nmcli device wifi hotspot ifname "$IFACE" ssid "$SSID" password "$PASS"; then
  echo "Could not start the hotspot. Check that your Wi-Fi card supports AP mode:"
  echo "  iw list | grep -A 10 'Supported interface modes'"
  exit 1
fi

# Find the name NetworkManager gave it
HOTSPOT_CON=$(nmcli -t -f NAME,DEVICE connection show --active | awk -F: -v dev="$IFACE" '$2==dev {print $1; exit}')
echo "Hotspot connection: ${HOTSPOT_CON:-unknown}"

echo
echo "Join the Wi-Fi: $SSID  (password: $PASS)"
if command -v qrencode >/dev/null; then
  qrencode -t ansiutf8 "WIFI:T:WPA;S:$SSID;P:$PASS;;"
fi
echo

# ---------- Run the server ----------
node server.js
CODE=$?

echo
echo "Server stopped (exit code $CODE)."
exit $CODE
