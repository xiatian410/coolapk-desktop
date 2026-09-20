# 数字联盟ID 一键生成器

为酷安桌面版生成**真实注册**的数字联盟ID（数盟可信ID），用于修复评论、发帖等写操作的服务端设备校验。

## 原理

数字联盟ID 由数盟 SDK 采集设备硬件指纹后本地计算，并注册到数盟服务器（绑定酷安的 apiKey）。它**不随软件信息变化**——同一台设备（含同一模拟器实例）永远生成同一个 ID，这正是“每人一个、设备唯一”的设计。

本工具在本地 Android 模拟器中运行数盟 SDK（已注入酷安官方 apiKey，从官方 APK 的 `assets/cn.shuzilm.config.json` 提取），并将 SDK 内置的已停用注册端点重定向到数盟现役服务器，从而：

- 每台电脑（模拟器指纹）得到一个稳定的、真实注册的 ID
- 换一个 AVD（或修改模拟器硬件参数）即可得到新的 ID
- ID 在数盟侧注册时绑定的就是酷安的 apiKey，与官方客户端同源

## 依赖

- Android SDK（`emulator`、`platform-tools/adb`、`build-tools` 不需要）
- 系统镜像 `system-images;android-30;google_apis;x86_64`（32 位 ARM 翻译支持，且可 `adb root`）

没有镜像时安装：

```
sdkmanager "system-images;android-30;google_apis;x86_64"
```

## 使用

Windows：

```powershell
powershell -ExecutionPolicy Bypass -File generate-szlm-id.ps1
# 可选参数：
#   -SdkRoot D:\DevData\Android\Sdk   指定 Android SDK 路径
#   -KeepEmulator                     结束后保留模拟器（下次生成更快）
```

macOS / Linux：

```bash
./generate-szlm-id.sh
```

首次运行会创建 AVD 并冷启动（约 1-2 分钟），之后：

1. 自动 root 模拟器并重定向数盟端点
2. 安装并首启生成器 APK
3. 轮询读取生成的 ID，输出并复制到剪贴板（Windows）
4. 关闭模拟器（除非 -KeepEmulator）

把得到的 ID 填入 **酷安桌面版 → 设置 → 设备信息 → 数字联盟ID**，点“验证”确认可用（需先登录）。建议同时在“自定义设备指纹”中把机型调为常见真机型号。

## 注意

- 模拟器网络需能直连中国大陆 IP（数盟服务器在境内）。若公司网络/代理拦截，生成会失败。
- 数盟按 apiKey 注册计次（酷安付费），每次“清数据重跑”都会重新注册一次，请勿脚本刷量——每台设备生成一次即可复用。
- 共享/滥用他人 ID 会被风控封禁，封禁后对应设备无法使用酷安。
