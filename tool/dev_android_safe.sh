#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Keep the desktop responsive during dev runs.
export GRADLE_OPTS="-Dorg.gradle.jvmargs='-Xmx2048m -XX:MaxMetaspaceSize=512m -XX:ReservedCodeCacheSize=256m -Dkotlin.daemon.jvm.options=-Xmx512m'"

# Prefer a stable Android Studio JDK instead of any system EA Java.
if [ -d "/opt/android-studio-2025.3.1/android-studio/jbr" ]; then
  export JAVA_HOME="/opt/android-studio-2025.3.1/android-studio/jbr"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

# Start emulator with stability defaults from ~/.local/bin/emulator wrapper.
# Override AVD: AVD_NAME=Medium_Phone_API_36.0 ./tool/dev_android_safe.sh
avd_name="${AVD_NAME:-Medium_Phone_API_36.0}"

if ! adb devices | awk '{print $1}' | rg -q '^emulator-[0-9]+'; then
  nohup emulator -avd "$avd_name" >/tmp/chesswarss-emulator.log 2>&1 &
  echo "Starting emulator '$avd_name'..."
fi

# Wait up to 90s for emulator to show as a flutter target.
for _ in $(seq 1 45); do
  if flutter devices 2>/dev/null | rg -q 'emulator-[0-9]+'; then
    break
  fi
  sleep 2
done

# Run with lower process priority to avoid UI starvation.
exec nice -n 10 flutter run --debug --no-enable-impeller "$@"
