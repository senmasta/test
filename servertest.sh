#!/bin/bash

# Define the Git repository URL and local file paths
VERSION=0
REPO_URL="https://github.com/senmasta/test.git"
LOCAL_FILE="./servertest.sh"
UPDATE_DIR="update"
REMOTE_FILE="$UPDATE_DIR/servertest.sh"

# Clone or pull the Git repository (actually unnecessary since the directory is deleted after the update :/)
if [ -d "$UPDATE_DIR/.git" ]; then
  cd $UPDATE_DIR
  git pull
  cd ..
else
  git clone "$REPO_URL" $UPDATE_DIR
fi

# Check if local remote version is higher than local version
REMOTE_VERSION=$(cat "$REMOTE_FILE" | grep -oP "(?<=VERSION=)\d+")
LOCAL_VERSION=$(cat "$LOCAL_FILE" | grep -oP "(?<=VERSION=)\d+")
if [ "$REMOTE_VERSION" -gt "$LOCAL_VERSION" ]; then
  # Update and copy the script to the main directory, delete update directory and contents
  cd update && git pull && cp "servertest.sh" "../servertest.sh"
  cd .. && rm -rf $UPDATE_DIR
  echo "servertest updated to version $REMOTE_VERSION"
# run the updated version of the script
  exec "$LOCAL_FILE"
else
  rm -rf $UPDATE_DIR
  echo "servertest is already up to date"
fi

#main test script
cat fc.txt
start="$(date +"%T")"
echo "1/7 - Testing internet connectivity"
    if ping -q -c 1 -W 1 google.com >/dev/null; then
    sleep 2
            echo "Internet connection successfully established"
    else
            echo "Is the network cable connected?"
            echo "Please make sure that a network cable is connected and dhcp and dns are functional"
            echo "Exiting..."
            exit
    fi
echo "2/7 - Getting server information"
sleep 1

echo "Please input the server name, eg. RS-666"
read NUM

echo "Please input the Mainboard model"
read MAIN

read -p "Reset IPMI? (yes/no) " yn

case $yn in 
 	yes ) ipmi=1;;
 	no )  ipmi=0;;
 	* ) echo invalid response;
 		exit 1;;
esac

echo "Selected server $NUM"
echo "" > output.txt
echo "**Server: $NUM**" >> output.txt
echo "$NUM" > server.txt
sleep 1
echo "<br>" >> output.txt
if [ $ipmi -eq 1 ]
  then
    echo "3/7 - Resetting IPMI"
    echo "**IPMI**" >> output.txt
    ipmitool raw 0x30 0x40
    sleep 1
    echo  "Waiting 60s for IPMI to reboot"
    sleep 70
    echo "Enable DHCP Network Configuration"
    ipmitool lan set 1 ipsrc dhcp
    sleep 3
    echo "LAN Settings"
    echo "$(ipmitool lan print 1)" > temp.txt
    sleep 5
    sed -n '1p; 8,11p; 16,19p' temp.txt >> output.txt
    echo "Setting admin password to ADMIN"
    echo "$(ipmitool user set password 2 ADMIN)" > temp.txt
    echo "$(tail -1 temp.txt)" >> output.txt
    sleep 2
    echo "<br>" >> output.txt
  else
    echo "**IPMI Reset skipped**" >> output.txt
    echo "3/7 - Skipping IPMI reset"
fi
echo "4/7 - Getting HW information"
sleep 2
echo "<br>" >> output.txt
echo "**BIOS**" >> output.txt
echo "Vendor: $(sudo dmidecode -s bios-vendor)" >> output.txt
echo "Version $(sudo dmidecode -s bios-version)" >> output.txt
echo "Release date $(sudo dmidecode -s bios-release-date)" >> output.txt
echo "<br>" >> output.txt
echo "**Mainboard**" >> output.txt
echo "Model: $MAIN" >> output.txt
echo "Manufacturer: $(sudo dmidecode -s baseboard-manufacturer)" >> output.txt
echo "Product: $(sudo dmidecode -s baseboard-product-name)" >> output.txt
echo "Version: $(sudo dmidecode -s baseboard-version)" >> output.txt
echo "<br>" >> output.txt
echo "**CPU**" >> output.txt
CPU=$(grep -c ^processor /proc/cpuinfo)
echo "Number of Cores: $CPU" >> output.txt
echo "Processor family: $(sudo dmidecode -s processor-family)" >> output.txt
echo "Manufacturer: $(sudo dmidecode -s processor-manufacturer)" >> output.txt
echo "Version: $(sudo dmidecode -s processor-version)" >> output.txt
echo "Frequency: $(sudo dmidecode -s processor-frequency)" >> output.txt
echo "5/7 - Starting CPU Stress test (5 Minutes)"
echo "<br>" >> output.txt
echo "**Temperatures at Idle**" >> output.txt
echo "$(sensors)" >> output.txt
echo "<br>" >> output.txt
stress-ng -t 300s --cpu "$CPU" &>/dev/null &
echo "Getting CPU Temps while Stress testing"
sleep 5
timeout --foreground 150s watch -d -n1 sensors
echo "**Temperatures after 150s**" >> output.txt
echo "$(sensors)" >> output.txt
echo "<br>" >> output.txt
timeout --foreground 150s watch -d -n1 sensors
echo "5/7 - CPU Stress test finished"
sleep 3
echo "6/7 - Testing Network throughput (Upload)"
echo "**iperf Upload test**" >> output.txt
echo "Disabled" >> output.txt
# echo "$(iperf3 -c 192.168.202.120 -t 30s -i 3)" >> output.txt
echo "6/7 - Testing Network throughput (Download)"
echo "**iperf Download test**" >> output.txt
echo "Disabled" >> output.txt
# echo "$(iperf3 -c 192.168.202.120 -t 30s -i 3 -R)" >> output.txt
echo "7/7 - Submitting test results to Teams Channel"
end="$(date +"%T")"
echo "Test start: $start, Test end: $end" >> output.txt
sed -i 's/$/\ \\n\\n/g' output.txt

# initialize webhook for teams
COLOR="00a4fc"
TITLE="$(cat server.txt)"
MESSAGE="$(cat output.txt)"
JSON="{\"title\": \"${TITLE}\", \"themeColor\": \"${COLOR}\", \"text\": \"${MESSAGE}\" }"

# send test results to teams channel
curl -H "Content-Type: application/json" -d "${JSON}" "${WEBHOOK_URL}"

echo ""
echo "7/7 - Goodbye"
