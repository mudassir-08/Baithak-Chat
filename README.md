# LocalShare

Offline chat and file sharing over a local Wi-Fi hotspot. No internet needed.
One laptop creates the hotspot and runs the server. Phones and computers join
the Wi-Fi and use it in the browser, with nothing to install on them.

## Features
- Real-time group chat and private chat
- Share files and pictures in the chat with the + button
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
npm start
```
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

## Author
Muhammad Owais
