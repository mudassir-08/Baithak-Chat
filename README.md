# Baithak

Offline chat and file sharing over a local Wi-Fi hotspot. No internet needed.
One laptop creates the hotspot and runs the server. Phones and computers join
the Wi-Fi and use it in the browser, with nothing to install on them.

## Features
- Real-time group chat and private chat
- Share files and pictures in the chat with the + button
- Record voice messages in chat or upload audio recordings, with in-chat playback
- Online users list
- Admin-protected file deletion

## Requirements
- Linux with NetworkManager (Kali, Ubuntu, etc.)
- Node.js 18 or newer
- A Wi-Fi adapter that supports AP (hotspot) mode
  (check with: `iw list | grep -A 10 "Supported interface modes"`)

## Run
```bash
git clone https://github.com/YOUR_USERNAME/localshare.git
cd localshare
./start.sh
```

Join the Wi-Fi shown in the terminal, then open the address it prints
(usually http://10.42.0.1:3000) in a browser.

Options: `./start.sh -s MyNetwork -p mypassword123 -i wlan0`

The terminal also prints an admin password, which is needed to delete shared
files. To set your own: `ADMIN_PASSWORD=mypass ./start.sh`

## No hotspot / other systems
On Windows, macOS, or any machine without NetworkManager, turn on your normal
hotspot (or connect everyone to the same router), then run:

```bash
npm install
node server.js
```

On the same computer, open `http://localhost:3000` to test voice recording;
modern browsers allow microphone access on localhost. To record from phones or
other devices on the local network, serve Baithak over HTTPS. This does not
require an internet connection, but the certificate must be trusted by each
device and include the server's IP address or hostname in its subject
alternative names (SAN). Set both certificate paths before starting:

```powershell
$env:TLS_KEY_PATH = "C:\certs\baithak-key.pem"
$env:TLS_CERT_PATH = "C:\certs\baithak-cert.pem"
node server.js
```

On Linux or macOS, start the server with:

```bash
TLS_KEY_PATH=/path/to/key.pem TLS_CERT_PATH=/path/to/cert.pem node server.js
```

With both variables set, the server uses HTTPS on port 3000; without them it
continues to use HTTP. The audio button uploads a recording from the device,
and the microphone button records a voice message directly in the chat.

## Android (Termux)
1. Install Termux from F-Droid.
2. Run:
```bash
pkg update && pkg install nodejs git -y
git clone https://github.com/YOUR_USERNAME/localshare.git
cd localshare && ./start.sh
```
3. Turn on your phone's hotspot. Other devices join it and open
   `http://<hotspot IP>:3000` (often 192.168.43.1). On the phone itself, use
   `http://localhost:3000`.


## Notes
- Traffic is plain HTTP and not encrypted. Use it only on a network you trust.
- Chat history is kept in memory and cleared when the server restarts.

## License
MIT

## Authors
Muhammad Owais
Muhammad Shoaib
Muhammad Mudassir Iqbal
