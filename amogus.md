(1) initial setup:

A. on android, get [termux](https://github.com/termux/termux-app/releases/latest), either universal apk or specific to your device architecture. then connect to data/wifi, install and open termux, then run:
```
pkg update
pkg upgrade -y
termux-setup-storage
```
B. on linux (debian or debian based), just have a usable terminal and have your packages somewhat updated
   
C. on wsl (windows), idk just have a download folder ig and update your packages

D. on macos, pray that apple doesn't screw with this.

(2) install dependencies:
```
apt install curl grep imagemagick sed mktemp
```
run with sudo if needed

(3) get script (latest version):
```
curl -o getabp.sh https://raw.githubusercontent.com/AkemiFurukawa91/Time-Machine-Sussy-Baka-Script/main/timemachine.sh
```
(4) run script:
```
bash getabp.sh DD-MM-YYYY
```
