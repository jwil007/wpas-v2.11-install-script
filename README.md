# wpas-v2.11-install-script
Shell script to build, install, and upgrade to wpa_supplicant version v2.11.

Automatically downloads and builds wpa_supplicant version 2.11, which is often needed for better 6GHz/Wi-Fi7 behavior.

Most Debian based distros are shipped with v2.10 as of March 2026, so this manual upgrade may be needed if 6GHz band testing is important.

## Instructions
1. Clone the repo.
2. Run `chmod +x install_wpa_supplicant_2.11.sh`
3. Run `sudo ./install_wpa_supplicant_2.11.sh`
4. Verify by running `wpa_supplicant -v`

The wpa_supplicant service is restarted at the end of the script. If you have an active Wi-Fi connection, you will be briefly disconnected. Existing SSID configuration should be maintained.



>[!CAUTION]
> This script replaces your existing wpa_supplicant binary. You should use this only on machines you are using for Wi-Fi testing, or if you have another specific usecase for v2.11. apt-get upgrade may move you back to v2.10.

