#!/bin/zsh
# Regenerates the App Store screenshots: seeds demo games into the app on an iPhone 6.9"
# and an iPad 13" simulator, captures each screen, then adds the captions (frame.py).
# Run from anywhere; needs Xcode and Pillow (pip install pillow).
set -e
HERE=${0:A:h}
IOS=${HERE:h:h}
WORK=$IOS/build/screenshots
BID=com.albertvila.podrida
PHONE_NAME="iPhone 17 Pro Max"
IPAD_NAME="iPad Pro 13 (App Store)"
IPAD_TYPE=com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB

mkdir -p $WORK/raw
cd $WORK
python3 $HERE/states.py

xcodebuild -project $IOS/Podrida.xcodeproj -scheme Podrida -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath $WORK/dd build -quiet
APP=$WORK/dd/Build/Products/Debug-iphonesimulator/Podrida.app

device_id() { xcrun simctl list devices available | grep -F "$1 (" | head -1 | grep -oE '[0-9A-F-]{36}' }
PHONE=$(device_id "$PHONE_NAME")
IPAD=$(device_id "$IPAD_NAME")
[[ -z $IPAD ]] && IPAD=$(xcrun simctl create "$IPAD_NAME" $IPAD_TYPE)

for D in $PHONE $IPAD; do
  [[ $D == $PHONE ]] && dev=iphone || dev=ipad
  xcrun simctl boot $D 2>/dev/null || true
  xcrun simctl bootstatus $D -b >/dev/null
  xcrun simctl install $D $APP
  xcrun simctl status_bar $D override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
  PREFS=$(xcrun simctl get_app_container $D $BID data)/Library/Preferences/$BID
  # Skip the first-launch introduction so every capture shows the screen it seeds.
  xcrun simctl spawn $D defaults write "$PREFS" hasSeenOnboarding -bool true
  for s in ledger warning crowd setup; do
    xcrun simctl terminate $D $BID 2>/dev/null || true
    if [[ $s == setup ]]; then
      xcrun simctl spawn $D defaults delete "$PREFS" game 2>/dev/null || true
    else
      xcrun simctl spawn $D defaults write "$PREFS" game -data $(xxd -p $s.json | tr -d '\n')
    fi
    xcrun simctl launch $D $BID >/dev/null
    sleep 5
    xcrun simctl io $D screenshot $WORK/raw/$dev-$s.png >/dev/null 2>&1
    echo "captured $dev $s"
  done
done

python3 $HERE/frame.py --raw $WORK/raw --out $IOS/AppStore/screenshots
