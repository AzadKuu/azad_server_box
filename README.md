English | [简体中文](README_zh.md)

<h2 align="center">AzadHub</h2>

<div align="center">
  <img alt="lang" src="https://img.shields.io/badge/lang-dart-cyan">
  <img alt="license" src="https://img.shields.io/badge/license-AGPLv3-yellow">
  <img alt="platform" src="https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Linux%20%7C%20Windows%20%7C%20HarmonyOS-blue">
</div>

<p align="center">
A Flutter app to monitor and manage Linux/Unix/Windows servers — <b>forked from <a href="https://github.com/lollipopkit/flutter_server_box">flutter_server_box</a></b> with <b>HarmonyOS (OHOS) support</b> as the primary addition.
<br><br>
Status charts (CPU, mem, disk, net…), SSH terminal, SFTP, Docker & process & systemd management, S.M.A.R.T, and more — now also running on HarmonyOS devices.
</p>

---

## 📥 Installation

| Platform | Source |
|--|--|
| HarmonyOS | Build from source — see [HarmonyOS build](#-harmonyos-build) below (HAP not distributed yet) |
| Android | [GitHub releases](https://github.com/AzadKuu/azad_server_box/releases) / [upstream](https://github.com/lollipopkit/flutter_server_box/releases) |
| iOS | [AppStore](https://apps.apple.com/app/id1586449703) / [upstream](https://github.com/lollipopkit/flutter_server_box/releases) (`_NoSign.ipa`, unsigned) |
| macOS | [AppStore](https://apps.apple.com/app/id1586449703) / [upstream](https://github.com/lollipopkit/flutter_server_box/releases) (`.dmg`) / `brew install --cask server-box` |
| Linux / Windows | [GitHub releases](https://github.com/AzadKuu/azad_server_box/releases) / [upstream](https://github.com/lollipopkit/flutter_server_box/releases) |

> Pre-built packages for Android/Linux/Windows are published in this repo's [Releases](https://github.com/AzadKuu/azad_server_box/releases) when available; iOS/macOS builds use the upstream signing & store listings. Only download from sources you trust.

## 🔖 Features

- **Status charts** (CPU, sensors, GPU…), **SSH terminal**, **SFTP**, **Docker & process & systemd**, **S.M.A.R.T**…
- **HarmonyOS support** — runs on HarmonyOS phone / tablet / 2-in-1 devices (see [adaptation status](#adaptation-status))
- Platform specific: `Bio auth`, `Msg push`, `Home widget`, `watchOS App` (iOS/Android only)
- Localization: English, 简体中文; Deutsch, 繁體中文, Indonesian, Français, Dutch, Türkçe, Українська мова, Español, Русский язык, Português, 日本語

## 📱 Screenshots

<table>
  <tr>
    <td><img width="200px" src="https://cdn.lpkt.cn/serverbox/screenshot/1.jpg"></td>
    <td><img width="200px" src="https://cdn.lpkt.cn/serverbox/screenshot/2.jpg"></td>
    <td><img width="200px" src="https://cdn.lpkt.cn/serverbox/screenshot/3.jpg"></td>
    <td><img width="200px" src="https://cdn.lpkt.cn/serverbox/screenshot/4.jpg"></td>
  </tr>
</table>

## 🔀 Changes vs upstream

### HarmonyOS platform support
- Added `Pfs.ohos` enum, `isOhos` detection, and `pickFilePath` / `pickFilePaths` via a custom `azad/file_picker` MethodChannel
- Registered `azad/clipboard`, `azad/ime`, `azad/locale`, `azad/device_info`, `azad/file_picker` channels in `EntryAbility.ets`
- Fixed white-screen crash caused by `libsqlite3mc.so` (Linux glibc version overwritten by build hook → replaced with HarmonyOS musl version in `flutter-hvigor-plugin.ts`)
- Bundled native libs (`libflutter_pty.so`, `libsbm_ffi.so`, `libsqlite3mc.so`) for `arm64-v8a`

### Terminal & SSH
- Fixed terminal text selection (`HitTestBehavior.deferToChild` → `opaque` in xterm `gesture_handler.dart`)
- Multi-line paste now shows a confirmation dialog with a 5-line preview
- Disconnect dialog replaced infinite-loop bug with a **Reconnect** / **Close** choice
- Reconnect progress dialog now correctly closes (`popDialog` instead of `pop` — root navigator vs page navigator)
- Tabs without tmux auto-close on disconnect instead of spinning reconnect attempts
- Connection health check tuned for VPN: ping timeout 10s→30s, failure threshold 3→5

### File transfer
- Multi-file upload: system picker now supports selecting multiple files at once
- Upload progress floating window (top-right, compact) with per-file progress bars, speed, and a close button
- Toast notification when upload starts

### UI / UX
- About page simplified to repo + upstream links only
- Update check points to this fork's GitHub releases
- Auto-update disabled by default
- App name changed to "AzadHub"
- SFTP sidebar slides in from the right edge
- Terminal toolbar file button added
- AI conversation code blocks now have a per-block copy button
- Dev toast spam on debug launch removed

### Windows build fixes
- Fixed missing DLL issue: `flutter_rust_bridge_hooks` redirects cargo output to Temp on Windows; added `_fixMissingWindowsDll()` fallback copy
- Fixed native assets not copied to debug output: added `install(DIRECTORY ...)` rule in `CMakeLists.txt`

## 🔧 HarmonyOS build

This fork adds a HarmonyOS (`ohos/`) project that embeds the Flutter app via the [`@ohos/flutter_ohos`](https://github.com/flutter/flutter) embedder.

### Prerequisites

- [DevEco Studio](https://developer.huawei.com/consumer/cn/download/deveco-studio) (HarmonyOS IDE)
- HarmonyOS SDK **5.1.0(18)+** (API 26)
- Flutter **3.44.9+** with the `flutter_ohos` toolchain
- Rust toolchain (for the native `sbm_ffi` crate, built via `hook/build.dart`)

### Build steps

1. **Install deps** — from the repo root:
   ```bash
   make deps
   ```
2. **Generate Flutter assets** for HarmonyOS:
   ```bash
   flutter build hap --debug
   # or, for a release build:
   flutter build hap --release
   ```
3. **Open & run in DevEco Studio** — open the `ohos/` directory, select a device or emulator, and click Run. The HAP is output under `ohos/entry/build/default/outputs/default/`.

> If you only need to iterate on the ArkTS shell (entry ability, IME handling), skip step 2 and edit files under `ohos/entry/src/main/ets/` directly in DevEco Studio.

### Adaptation status

The HarmonyOS port is **at an early-usable stage**. What works:

- ✅ App boots and renders the full Flutter UI
- ✅ Server status charts (CPU, memory, disk, network)
- ✅ SSH terminal (including backspace via a custom IME MethodChannel handler)
- ✅ SFTP file browsing & multi-file upload
- ✅ Terminal text selection & copy
- ✅ Multi-line paste confirmation
- ✅ Disconnect / reconnect flow
- ✅ Native libs (`libflutter_pty.so`, `libsbm_ffi.so`, `libsqlite3mc.so`) bundled for `arm64-v8a`

Known limitations:

- ⚠️ HarmonyOS-only platform features (push notifications, home widget, bio auth) are **not** wired up yet
- ⚠️ The `flutter_ohos` embedder and `xterm` submodule are forked — see [Submodules](#-submodules) below
- ⚠️ Only `arm64-v8a` is shipped; `x86_64` (emulator) may need extra build config
- ⚠️ DevEco Studio Run button defaults to debug mode; release HAP must be built via Build > Build Hap(s)

### TODO

- [ ] HarmonyOS phone not detected as mobile — virtual key bar not showing
- [ ] Foldable screen half-open virtual keyboard layout
- [x] File upload / download
- [x] Multi-file upload
- [x] Upload progress floating window
- [x] Cannot copy text in terminal
- [x] Cannot select text in terminal
- [x] Multi-line paste should require user confirmation
- [x] Disconnect dialog cannot be dismissed — should ask user whether to reconnect
- [x] About page adjustments
- [x] AI code block copy button
- [x] Windows terminal native assets copy
- [x] Update check points to this fork

### Submodules

This repo uses vendored forks as git submodules under `packages/`. The `xterm` submodule points to [AzadKuu/xterm.dart](https://github.com/AzadKuu/xterm.dart) (branch `ohos`) which carries the OHOS IME adaptation. The `fl_lib` submodule points to [AzadKuu/fl_lib](https://github.com/AzadKuu/fl_lib). After cloning:

```bash
git submodule update --init --recursive
```

## 🆘 Help

<div align="center">
  <a href="https://qm.qq.com/q/daCGa7eShG"><img alt="qq" src="https://img.shields.io/badge/QQ-Group-pink"></a>
  <a href="https://t.me/lpktg"><img alt="telegram" src="https://img.shields.io/badge/Telegram-lpktg-green"></a>
  <a href="https://discord.gg/SsVNbRhK7w"><img alt="discord" src="https://img.shields.io/badge/Discord-lpkt-purple"></a>
</div>

- For **HarmonyOS-specific** issues, open an issue in this repo: [AzadKuu/azad_server_box/issues](https://github.com/AzadKuu/azad_server_box/issues/new).
- For general app issues, also check the [upstream wiki](https://github.com/lollipopkit/flutter_server_box/wiki).
- [ServerBox Monitor](https://github.com/lollipopkit/flutter_server_box/tree/main/monitor) is an agent you install on your servers for message push, home widgets, the watch app, and HTTP-based server access. See its [README](https://github.com/lollipopkit/flutter_server_box/blob/main/monitor/README.md) for setup.

Before opening an issue:

1. Paste the **entire log** (click the top right of the home page) in the issue template.
2. Make sure the issue is caused by this app, not by your server or network.
3. For HarmonyOS issues, note your device type (`phone` / `tablet` / `2in1`) and HarmonyOS version.

## 🧱 Contributions

Contributions are welcome — especially HarmonyOS improvements. See [CONTRIBUTING.md](CONTRIBUTING.md) for the development setup and commit convention.

### Development

1. Setup [Flutter](https://flutter.dev/docs/get-started/install) and [Rust](https://rustup.rs).
2. Clone this repo with submodules: `git clone --recursive https://github.com/AzadKuu/azad_server_box.git`
3. Run `make deps` then `make run` to start the app on a non-HarmonyOS platform.
4. For HarmonyOS, follow the [HarmonyOS build](#-harmonyos-build) steps.
5. Run `dart run fl_build -p PLATFORM` to build for a specific platform.

### Translation

- See the [upstream translation guide](https://blog.lpkt.cn/posts/faq/). PRs are welcome.

## 🙏 Acknowledgements

This project is a fork of **[flutter_server_box](https://github.com/lollipopkit/flutter_server_box)** by [@lollipopkit](https://github.com/lollipopkit), with gratitude for the original work and its contributors.

Key upstream dependencies that this fork also relies on:
- [dartssh2](https://github.com/TerminalStudio/dartssh2) — SSH client
- [xterm.dart](https://github.com/TerminalStudio/xterm.dart) — terminal emulator (forked for OHOS IME)
- [fl_lib](https://github.com/AzadKuu/fl_lib) — shared utilities (forked)

## 📝 License

`AGPL v3` — inherited from the upstream project. See [LICENSE](LICENSE).
