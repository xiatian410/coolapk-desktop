#!/usr/bin/env bash
# 数字联盟ID 一键生成器（macOS / Linux）
# 依赖：Android SDK + system-images;android-30;google_apis;x86_64
set -euo pipefail

AVD_NAME="szlm-gen"
PKG="com.github.gavin.smid"
ACTIVITY="com.github.gavin.smid/com.github.gavinme.smid.MainActivity"
OLD_SZLM_IP="185.45.5.35"   # 老版 SDK 内置的已停用端点

SDK_ROOT="${1:-${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}}"
if [[ -z "$SDK_ROOT" ]]; then
  for p in "$HOME/Android/Sdk" "$HOME/Library/Android/sdk" "/opt/android-sdk" "/d/DevData/Android/Sdk"; do
    [[ -x "$p/platform-tools/adb" ]] && SDK_ROOT="$p" && break
  done
fi
[[ -z "$SDK_ROOT" || ! -x "$SDK_ROOT/platform-tools/adb" ]] && {
  echo "未找到 Android SDK，用法: $0 <sdk路径>（需包含 platform-tools 与 emulator）"; exit 1; }
ADB="$SDK_ROOT/platform-tools/adb"
EMU="$SDK_ROOT/emulator/emulator"
echo "SDK: $SDK_ROOT"

[[ -f "$SDK_ROOT/system-images/android-30/google_apis/x86_64/kernel-ranchu" ]] || {
  echo "缺少镜像 system-images;android-30;google_apis;x86_64，请先: sdkmanager 'system-images;android-30;google_apis;x86_64'"; exit 1; }

# ── 创建 AVD（手写配置）─────────────────────────────────────────
AVD_HOME="${ANDROID_AVD_HOME:-$HOME/.android/avd}"
mkdir -p "$AVD_HOME/$AVD_NAME.avd"
cat > "$AVD_HOME/$AVD_NAME.ini" <<EOF
avd.ini.encoding=UTF-8
path=$AVD_HOME/$AVD_NAME.avd
path.rel=avd/$AVD_NAME.avd
target=android-30
EOF
cat > "$AVD_HOME/$AVD_NAME.avd/config.ini" <<EOF
avd.ini.encoding = UTF-8
AvdId = $AVD_NAME
PlayStore.enabled = false
abi.type = x86_64
avd.ini.displayname = $AVD_NAME
disk.dataPartition.size = 2147483648
fastboot.forceColdBoot = yes
hw.cpu.arch = x86_64
hw.cpu.ncore = 4
hw.device.name = pixel_4
hw.gpu.enabled = yes
hw.gpu.mode = guest
hw.lcd.density = 440
hw.lcd.height = 2280
hw.lcd.width = 1080
hw.ramSize = 3072
image.sysdir.1 = system-images/android-30/google_apis/x86_64/
tag.id = google_apis
vm.heapSize = 256
EOF
echo "AVD 已就绪: $AVD_NAME"

# ── 解析数盟现役服务器 ───────────────────────────────────────────
SZLM_IP="$( (getent hosts api.shuzilm.cn 2>/dev/null || nslookup api.shuzilm.cn 2>/dev/null) | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
[[ -z "$SZLM_IP" ]] && SZLM_IP="47.95.162.60"
echo "数盟服务器: api.shuzilm.cn -> $SZLM_IP"

# ── 启动模拟器 ───────────────────────────────────────────────────
echo "启动模拟器（首次冷启动约 1-2 分钟）..."
"$ADB" kill-server >/dev/null 2>&1 || true
"$EMU" -avd "$AVD_NAME" -no-snapshot -no-boot-anim -gpu guest -no-metrics -memory 3072 >/dev/null 2>&1 &
EMU_PID=$!
trap 'kill $EMU_PID 2>/dev/null || true' EXIT

"$ADB" wait-for-device
for _ in $(seq 1 100); do
  [[ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]] && break
  sleep 3
done
[[ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]] || { echo '模拟器启动超时'; exit 1; }
echo "模拟器已启动"

"$ADB" root >/dev/null; sleep 3
"$ADB" shell "iptables -t nat -A OUTPUT -d $OLD_SZLM_IP -p tcp -j DNAT --to-destination $SZLM_IP"
echo "已重定向数盟端点: $OLD_SZLM_IP -> $SZLM_IP"

"$ADB" install -r -t "$(dirname "$0")/SmidGen.apk" >/dev/null
"$ADB" shell "pm clear $PKG" >/dev/null
"$ADB" shell "am start -n $ACTIVITY" >/dev/null
echo "等待数盟 SDK 采集指纹并注册（约 20-60 秒）..."

ID=""
for _ in $(seq 1 24); do
  sleep 5
  XML="$("$ADB" shell "cat /data/data/$PKG/shared_prefs/${PKG}_dna.xml 2>/dev/null")"
  ID="$(echo "$XML" | grep -oE 'name="device_id">[^<]+' | sed 's/.*">//')"
  [[ -n "$ID" ]] && break
done
[[ -z "$ID" ]] && { echo "生成超时：请确认可直连中国大陆网络（数盟服务器在境内）"; exit 1; }

echo ""
echo "========== 数字联盟ID 生成成功 =========="
echo "$ID"
echo "========================================"
echo "填入：酷安桌面版 → 设置 → 设备信息 → 数字联盟ID，然后点\"验证\"（需先登录）"
