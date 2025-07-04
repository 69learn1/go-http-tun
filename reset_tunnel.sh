#!/bin/bash

# Coler Code
Purple='\033[0;35m'
Cyan='\033[0;36m'
cyan='\033[0;36m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
White='\033[0;96m'
RED='\033[0;31m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

	clear
echo  "
══════════════════════════════════════════════════════════════════════════════════════
 

══════════════════════════════════════════════════════════════════════════════════════"

# Determine the architecture and set the ASSET_NAME accordingly
ARCH=$(uname -m)
if [ "$ARCH" == "aarch64" ]; then
  ASSET_NAME="Waterwall-linux-arm64.zip"
elif [ "$ARCH" == "x86_64" ]; then
  ASSET_NAME="Waterwall-linux-64.zip"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

# Function to download and unzip the release
download_and_unzip() {
  local url="$1"
  local dest="$2"

  echo "Downloading $dest from $url..."
  wget -q -O "$dest" "$url"
  if [ $? -ne 0 ]; then
    echo "Error: Unable to download file."
    return 1
  fi

  echo "Unzipping $dest..."
  unzip -o "$dest"
  if [ $? -ne 0 ]; then
    echo "Error: Unable to unzip file."
    return 1
  fi
  
  sleep 0.5
  chmod +x Waterwall
  rm "$dest"

  echo "Download and unzip completed successfully."
}

# Function to get download URL for the latest release
get_latest_release_url() {
  local api_url="https://api.github.com/repos/radkesvat/WaterWall/releases/latest"

  echo "Fetching latest release data..." >&2
  local response=$(curl -s "$api_url")
  if [ $? -ne 0 ]; then
    echo "Error: Unable to fetch release data." >&2
    return 1
  fi

  local asset_url=$(echo "$response" | jq -r ".assets[] | select(.name == \"$ASSET_NAME\") | .browser_download_url")
  if [ -z "$asset_url" ]; then
    echo "Error: Asset not found." >&2
    return 1
  fi

  echo "$asset_url"
}

# Function to get download URL for a specific release version
get_specific_release_url() {
  local version=$1
  local api_url="https://api.github.com/repos/radkesvat/WaterWall/releases/tags/$version"

  echo "Fetching release data for version $version..." >&2
  response=$(curl -s $api_url)
  if [ $? -ne 0 ]; then
    echo "Error: Unable to fetch release data for version $version." >&2
    exit 1
  fi

  local asset_url=$(echo $response | jq -r ".assets[] | select(.name == \"$ASSET_NAME\") | .browser_download_url")
  if [ -z "$asset_url" ]; then
    echo "Error: Asset not found for version $version." >&2
    exit 1
  fi

  echo $asset_url
}

setup_waterwall_service() {
    cat > /etc/systemd/system/waterwall.service << EOF
[Unit]
Description=Waterwall Service
After=network.target

[Service]
ExecStart=/root/RRT/Waterwall
WorkingDirectory=/root/RRT
Restart=always
RestartSec=5
User=root
StandardOutput=null
StandardError=null

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable waterwall
    systemctl start waterwall
}

while true; do
    echo -e "${Purple}Select an option:${NC}"
    echo -e "${White}1. IRAN ${NC}"
    echo -e "${Cyan}2. KHAREJ ${NC}"
    echo -e "${White}3. Uninstall${NC}"
    echo -e "${Cyan}0. Exit ${NC}"

    read -p "Enter your choice: " choice
    if [[ "$choice" -eq 1 || "$choice" -eq 2 ]]; then
        SSHD_CONFIG_FILE="/etc/ssh/sshd_config"
        CURRENT_PORT=$(grep -E '^(#Port |Port )' "$SSHD_CONFIG_FILE")

        if [[ "$CURRENT_PORT" != "Port 22" && "$CURRENT_PORT" != "#Port 22" ]]; then
            sudo sed -i -E 's/^(#Port |Port )[0-9]+/Port 22/' "$SSHD_CONFIG_FILE"
            echo "SSH Port has been updated to Port 22."
            sudo systemctl restart sshd
            sudo service ssh restart
        fi
        sleep 0.5
        mkdir /root/RRT
        cd /root/RRT
        apt install unzip -y
        apt install jq -y

        read -p "Do you want to install the latest version? (y/n): " answer
        if [[ "$answer" == [Yy]* ]]; then
            # Get the latest release URL
            url=$(get_latest_release_url)

            if [ $? -ne 0 ] || [ -z "$url" ]; then
                echo "Failed to retrieve the latest release URL."
                exit 1
            fi
            echo "Latest Release URL: $url"
            download_and_unzip "$url" "$ASSET_NAME"
            if [ $? -ne 0 ]; then
                echo "Failed to download or unzip the file."
                exit 1
            fi
        elif [[ "$answer" == [Nn]* ]]; then
            read -p "Enter the version you want to install (e.g., v1.18): " version
            # Get the specific release URL
            url=$(get_specific_release_url "$version")

            if [ $? -ne 0 ] || [ -z "$url" ]; then
                echo "Failed to retrieve the latest release URL."
                exit 1
            fi
            echo "Specific Version URL: $url"
            download_and_unzip "$url" "$ASSET_NAME"
        else
            echo "Please answer yes (y) or no (n)."
            break
        fi

        cat > core.json << EOF
{
    "log": {
        "path": "log/",
        "core": {
            "loglevel": "DEBUG",
            "file": "core.log",
            "console": true
        },
        "network": {
            "loglevel": "DEBUG",
            "file": "network.log",
            "console": true
        },
        "dns": {
            "loglevel": "SILENT",
            "file": "dns.log",
            "console": false
        }
    },
    "dns": {},
    "misc": {
        "workers": 0,
        "ram-profile": "server",
        "libs-path": "libs/"
    },
    "configs": [
        "config.json"
    ]
}
EOF
    fi

    if [ "$choice" -eq 1 ]; then
        public_ip=$(wget -qO- https://api.ipify.org)
        echo -e "${Cyan}You chose Iran.${NC}"
        read -p "enter Kharej Ipv4: " ip_remote
        cat > config.json << EOF
{
    "name": "iran",
    "nodes": [
        {
            "name": "my tun",
            "type": "TunDevice",
            "settings": {
                "device-name": "wtun0",
                "device-ip": "10.10.0.1/24"
            },
            "next": "ipovsrc"
        },
        {
            "name": "ipovsrc",
            "type": "IpOverrider",
            "settings": {
                "direction": "up",
                "mode": "source-ip",
                "ipv4": "127.0.0.1"
            },
            "next": "ipovdest"
        },
        {
            "name": "ipovdest",
            "type": "IpOverrider",
            "settings": {
                "direction": "up",
                "mode": "dest-ip",
                "ipv4": "$ip_remote"
            },
            "next": "manip"
        },
        {
            "name": "manip",
            "type": "IpManipulator",
            "settings": {
                "protoswap": 18
            },
            "next": "ipovsrc2"
        },
        {
            "name": "ipovsrc2",
            "type": "IpOverrider",
            "settings": {
                "direction": "down",
                "mode": "source-ip",
                "ipv4": "10.10.0.2"
            },
            "next": "ipovdest2"
        },
        {
            "name": "ipovdest2",
            "type": "IpOverrider",
            "settings": {
                "direction": "down",
                "mode": "dest-ip",
                "ipv4": "10.10.0.1"
            },
            "next": "rd"
        },
        {
            "name": "rd",
            "type": "RawSocket",
            "settings": {
                "capture-filter-mode": "source-ip",
                "capture-ip": "$ip_remote"
            }
        },
        {
            "name": "input1",
            "type": "TcpListener",
            "settings": {
                "address": "0.0.0.0",
                "port": 443,
                "nodelay": true
            },
            "next": "output1"
        },
        {
            "name": "output1",
            "type": "TcpConnector",
            "settings": {
                "nodelay": true,
                "address": "10.10.0.2",
                "port": 443
            }
        }
    ]
}
EOF
        sleep 0.5
        setup_waterwall_service
        sleep 0.5
        echo -e "${Cyan}Iran IPv4 is: $public_ip${NC}"
        echo -e "${Purple}Kharej IPv4 is: $ip_remote${NC}"
        echo -e "${Cyan}SNI $HOSTNAME${NC}"
        echo -e "${Purple}Iran Setup Successfully Created ${NC}"
        read -p "Press Enter to continue"
    elif [ "$choice" -eq 2 ]; then
        public_ip=$(wget -qO- https://api.ipify.org)
        echo -e "${Purple}You chose Kharej.${NC}"
        read -p "enter Iran Ip: " ip_remote
        cat > config.json << EOF
{
    "name": "kharej",
    "nodes": [
        {
            "name": "my tun",
            "type": "TunDevice",
            "settings": {
                "device-name": "wtun0",
                "device-ip": "10.10.0.1/24"
            },
            "next": "ipovsrc"
        },
        {
            "name": "ipovsrc",
            "type": "IpOverrider",
            "settings": {
                "direction": "up",
                "mode": "source-ip",
                "ipv4": "127.0.0.1"
            },
            "next": "ipovdest"
        },
        {
            "name": "ipovdest",
            "type": "IpOverrider",
            "settings": {
                "direction": "up",
                "mode": "dest-ip",
                "ipv4": "$ip_remote"
            },
            "next": "manip"
        },
        {
            "name": "manip",
            "type": "IpManipulator",
            "settings": {
                "protoswap": 18
            },
            "next": "ipovsrc2"
        },
        {
            "name": "ipovsrc2",
            "type": "IpOverrider",
            "settings": {
                "direction": "down",
                "mode": "source-ip",
                "ipv4": "10.10.0.2"
            },
            "next": "ipovdest2"
        },
        {
            "name": "ipovdest2",
            "type": "IpOverrider",
            "settings": {
                "direction": "down",
                "mode": "dest-ip",
                "ipv4": "10.10.0.1"
            },
            "next": "rd"
        },
        {
            "name": "rd",
            "type": "RawSocket",
            "settings": {
                "capture-filter-mode": "source-ip",
                "capture-ip": "$ip_remote"
            }
        }
    ]
}
EOF
        sleep 0.5
        setup_waterwall_service
        sleep 0.5
        echo -e "${Purple}Kharej IPv4 is: $public_ip${NC}"
        echo -e "${Cyan}Iran IPv4 is: $ip_remote${NC}"
        echo -e "${Purple}SNI $HOSTNAME${NC}"
        echo -e "${Cyan}Kharej Setup Successfully Created ${NC}"
        read -p "Press Enter to continue"
    elif [ "$choice" -eq 3 ]; then
        sudo systemctl stop waterwall
        sudo systemctl disable waterwall
        rm -rf /etc/systemd/system/waterwall.service
        pkill -f Waterwall
        rm -rf /root/RRT
        echo "Removed"
        read -p "Press Enter to continue"
    elif [ "$choice" -eq 0 ]; then
        echo "Exit.."
        break
    else
        echo "Invalid choice. Please try again."
    fi
done