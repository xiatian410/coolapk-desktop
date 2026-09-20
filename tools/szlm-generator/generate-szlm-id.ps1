# 数字联盟ID 一键生成器（Windows）
# 依赖：Android SDK + system-images;android-30;google_apis;x86_64
param(
  [string]$SdkRoot = "",
  [switch]$KeepEmulator
)

# 原生工具（adb/emulator）会向 stderr 写非错误信息，EAP=Stop 会误杀，改用显式检查
$ErrorActionPreference = 'Continue'
$AvdName = 'szlm-gen'
$Pkg = 'com.github.gavin.smid'
$Activity = 'com.github.gavin.smid/com.github.gavinme.smid.MainActivity'
$OldSzlmIp = '185.45.5.35'   # 老版 SDK 内置的已停用端点

# ── 定位 Android SDK ─────────────────────────────────────────────
if (-not $SdkRoot) { $SdkRoot = $env:ANDROID_HOME }
if (-not $SdkRoot) { $SdkRoot = $env:ANDROID_SDK_ROOT }
if (-not $SdkRoot) {
  foreach ($p in @("D:\DevData\Android\Sdk", "$env:LOCALAPPDATA\Android\Sdk", "C:\Android\Sdk")) {
    if (Test-Path "$p\platform-tools\adb.exe") { $SdkRoot = $p; break }
  }
}
if (-not $SdkRoot -or -not (Test-Path "$SdkRoot\platform-tools\adb.exe")) {
  throw "未找到 Android SDK，请用 -SdkRoot 指定（需包含 platform-tools 与 emulator）"
}
$Adb = "$SdkRoot\platform-tools\adb.exe"
$Emulator = "$SdkRoot\emulator\emulator.exe"
Write-Host "SDK: $SdkRoot"

if (-not (Test-Path "$SdkRoot\system-images\android-30\google_apis\x86_64\kernel-ranchu")) {
  throw "缺少系统镜像 system-images;android-30;google_apis;x86_64，请先执行: sdkmanager `"system-images;android-30;google_apis;x86_64`""
}

# ── 创建 AVD（手写配置，绕过 avdmanager 的兼容问题）──────────────
$AvdHome = if ($env:ANDROID_AVD_HOME) { $env:ANDROID_AVD_HOME } else { "$env:USERPROFILE\.android\avd" }
New-Item -ItemType Directory -Force -Path "$AvdHome\$AvdName.avd" | Out-Null
Set-Content -Path "$AvdHome\$AvdName.ini" -Value @"
avd.ini.encoding=UTF-8
path=$AvdHome\$AvdName.avd
path.rel=avd\$AvdName.avd
target=android-30
"@
Set-Content -Path "$AvdHome\$AvdName.avd\config.ini" -Value @"
avd.ini.encoding = UTF-8
AvdId = $AvdName
PlayStore.enabled = false
abi.type = x86_64
avd.ini.displayname = $AvdName
disk.dataPartition.size = 2147483648
fastboot.forceColdBoot = yes
hw.accelerometer = yes
hw.audioInput = yes
hw.battery = yes
hw.camera.back = emulated
hw.camera.front = emulated
hw.cpu.arch = x86_64
hw.cpu.ncore = 4
hw.device.name = pixel_4
hw.gps = yes
hw.gpu.enabled = yes
hw.gpu.mode = guest
hw.lcd.density = 440
hw.lcd.height = 2280
hw.lcd.width = 1080
hw.ramSize = 3072
image.sysdir.1 = system-images\android-30\google_apis\x86_64\
tag.display = Google APIs
tag.id = google_apis
vm.heapSize = 256
"@
Write-Host "AVD 已就绪: $AvdName"

# ── 解析数盟现役服务器 IP（动态解析，端点 IP 可能变化）───────────
$SzlmIp = (Resolve-DnsName -Name api.shuzilm.cn -Type A -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
if (-not $SzlmIp) { $SzlmIp = '47.95.162.60' }
Write-Host "数盟服务器: api.shuzilm.cn -> $SzlmIp"

# ── 启动模拟器 ────────────────────────────────────────────────────
Write-Host "启动模拟器（首次冷启动约 1-2 分钟）..."
$null = & $Adb kill-server 2>$null
$EmuProc = Start-Process -FilePath $Emulator -ArgumentList @(
  '-avd', $AvdName, '-no-snapshot', '-no-boot-anim', '-gpu', 'guest',
  '-no-metrics', '-memory', '3072'
) -WindowStyle Hidden -PassThru

try {
  & $Adb wait-for-device | Out-Null
  $deadline = (Get-Date).AddMinutes(5)
  while ((Get-Date) -lt $deadline) {
    $boot = (& $Adb shell getprop sys.boot_completed 2>$null | Select-Object -First 1)
    if ("$boot".Trim() -eq '1') { break }
    Start-Sleep -Seconds 3
  }
  if ("$boot".Trim() -ne '1') { throw '模拟器启动超时' }
  Write-Host '模拟器已启动'

  # root + 端点重定向（SDK 内置端点已停用，重定向到现役服务器）
  & $Adb root | Out-Null
  Start-Sleep -Seconds 3
  & $Adb shell "iptables -t nat -A OUTPUT -d $OldSzlmIp -p tcp -j DNAT --to-destination $SzlmIp"
  Write-Host "已重定向数盟端点: $OldSzlmIp -> $SzlmIp"

  # 安装并首启生成器
  $Apk = Join-Path $PSScriptRoot 'SmidGen.apk'
  & $Adb install -r -t $Apk | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "生成器 APK 安装失败（exit $LASTEXITCODE）" }
  & $Adb shell "pm clear $Pkg" | Out-Null
  & $Adb shell "am start -n $Activity" | Out-Null
  Write-Host '等待数盟 SDK 采集指纹并注册（约 20-60 秒）...'

  # 轮询读取生成的 ID
  $Id = $null
  $deadline = (Get-Date).AddSeconds(120)
  while ((Get-Date) -lt $deadline -and -not $Id) {
    Start-Sleep -Seconds 5
    $xml = & $Adb shell "cat /data/data/$Pkg/shared_prefs/${Pkg}_dna.xml 2>/dev/null"
    if ("$xml" -match 'name="device_id">([^<]+)<') { $Id = $Matches[1] }
  }
  if (-not $Id) { throw '生成超时：请确认本机可直连中国大陆网络（数盟服务器在境内），且镜像支持 32 位 ARM 翻译' }

  Write-Host ''
  Write-Host '========== 数字联盟ID 生成成功 ==========' -ForegroundColor Green
  Write-Host $Id -ForegroundColor Yellow
  Write-Host '========================================' -ForegroundColor Green
  Write-Host '填入：酷安桌面版 → 设置 → 设备信息 → 数字联盟ID，然后点"验证"（需先登录）'
  try { Set-Clipboard -Value $Id; Write-Host '（已复制到剪贴板）' } catch {}
}
finally {
  if (-not $KeepEmulator) {
    & $Adb emu kill 2>$null | Out-Null
    if ($EmuProc -and -not $EmuProc.HasExited) { Stop-Process -Id $EmuProc.Id -Force -ErrorAction SilentlyContinue }
    Write-Host '模拟器已关闭'
  } else {
    Write-Host "模拟器保留运行（下次生成更快），手动关闭: $Adb -s emulator-5554 emu kill"
  }
}
