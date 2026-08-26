简体中文 | [English](README.md)

<h2 align="center">AzadHub</h2>

<div align="center">
  <img alt="语言" src="https://img.shields.io/badge/语言-dart-cyan">
  <img alt="license" src="https://img.shields.io/badge/证书-AGPLv3-yellow">
  <img alt="平台" src="https://img.shields.io/badge/平台-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Linux%20%7C%20Windows%20%7C%20HarmonyOS-blue">
</div>

<p align="center">
使用 Flutter 开发的服务器监控管理工具箱 —— <b>fork 自 <a href="https://github.com/lollipopkit/flutter_server_box">flutter_server_box</a></b>，核心新增 <b>鸿蒙（HarmonyOS）平台支持</b>。
<br><br>
提供状态图表（CPU、内存、磁盘、网络…）、SSH 终端、SFTP、Docker & 进程 & systemd 管理、S.M.A.R.T 等功能 —— 现已可在鸿蒙设备上运行。
</p>

---

## 📥 安装

| 平台 | 下载来源 |
|--|--|
| 鸿蒙 HarmonyOS | 需自行构建 —— 见下方[鸿蒙构建](#-鸿蒙构建)（暂未提供 HAP 安装包） |
| Android | [本仓库 Releases](https://github.com/AzadKuu/azad_server_box/releases) / [上游](https://github.com/lollipopkit/flutter_server_box/releases) |
| iOS | [AppStore](https://apps.apple.com/app/id1586449703) / [上游](https://github.com/lollipopkit/flutter_server_box/releases)（`_NoSign.ipa`，未签名，需自行签名） |
| macOS | [AppStore](https://apps.apple.com/app/id1586449703) / [上游](https://github.com/lollipopkit/flutter_server_box/releases)（`.dmg`） / `brew install --cask server-box` |
| Linux / Windows | [本仓库 Releases](https://github.com/AzadKuu/azad_server_box/releases) / [上游](https://github.com/lollipopkit/flutter_server_box/releases) |

> Android / Linux / Windows 的预编译包会发布在本仓库的 [Releases](https://github.com/AzadKuu/azad_server_box/releases) 中（如有）；iOS / macOS 使用上游的签名和商店发布。请只从信任的来源下载。

## 🔖 特点

- **状态图表**（CPU、传感器、GPU 等）、**SSH 终端**、**SFTP**、**Docker & 进程 & Systemd** 管理、**S.M.A.R.T**…
- **鸿蒙支持** —— 可在鸿蒙 phone / tablet / 2-in-1 设备上运行（见[适配状态](#适配状态)）
- 平台特殊功能：`生物认证`、`推送`、`桌面小部件`、`watchOS App`（仅 iOS/Android）
- 本地化：English, 简体中文; Deutsch, 繁體中文, Indonesian, Français, Dutch, Türkçe, Українська мова, Español, Русский язык, Português, 日本語

## 📱 截屏

<table>
  <tr>
    <td><img width="200px" src="https://cdn.lpkt.cn/serverbox/screenshot/1.jpg"></td>
    <td><img width="200px" src="https://cdn.lpkt.cn/serverbox/screenshot/2.jpg"></td>
    <td><img width="200px" src="https://cdn.lpkt.cn/serverbox/screenshot/3.jpg"></td>
    <td><img width="200px" src="https://cdn.lpkt.cn/serverbox/screenshot/4.jpg"></td>
  </tr>
</table>

## 🔧 鸿蒙构建

本 fork 新增了鸿蒙（`ohos/`）工程，通过 [`@ohos/flutter_ohos`](https://github.com/flutter/flutter) embedder 嵌入 Flutter 应用。

### 环境要求

- [DevEco Studio](https://developer.huawei.com/consumer/cn/download/deveco-studio)（鸿蒙 IDE）
- HarmonyOS SDK **5.1.0(18)+**（API 26）
- Flutter **3.44.9+**，带 `flutter_ohos` 工具链
- Rust 工具链（用于构建原生 `sbm_ffi` crate，通过 `hook/build.dart`）

### 构建步骤

1. **安装依赖** —— 在仓库根目录：
   ```bash
   make deps
   ```
2. **为鸿蒙生成 Flutter 产物**：
   ```bash
   flutter build hap --debug
   # 或 release 构建：
   flutter build hap --release
   ```
3. **用 DevEco Studio 打开并运行** —— 打开 `ohos/` 目录，选择设备或模拟器，点击运行。HAP 产物输出在 `ohos/entry/build/default/outputs/default/`。

> 如果只需调试 ArkTS 壳层（EntryAbility、IME 处理），可跳过第 2 步，直接在 DevEco Studio 中编辑 `ohos/entry/src/main/ets/` 下的文件。

### 适配状态

鸿蒙移植处于**初步可用阶段**。已支持：

- ✅ 应用启动并渲染完整 Flutter UI
- ✅ 服务器状态图表（CPU、内存、磁盘、网络）
- ✅ SSH 终端（含退格键，通过自定义 IME MethodChannel 处理）
- ✅ SFTP 文件浏览
- ✅ 原生库（`libflutter_pty.so`、`libsbm_ffi.so`、`libsqlite3mc.so`）已为 `arm64-v8a` 打包

已知限制：

- ⚠️ 鸿蒙特有功能（推送通知、桌面小部件、生物认证）**尚未**接入
- ⚠️ `flutter_ohos` embedder 和 `xterm` 子模块均为 fork —— 见下方[子模块](#子模块)说明
- ⚠️ 仅打包 `arm64-v8a`；`x86_64`（模拟器）可能需要额外构建配置

### 待办事项

- [ ] 鸿蒙手机未识别为移动端，虚拟快捷键栏不显示
- [x] 文件上传 / 下载
- [ ] AI 面板调整
- [ ] 关于页面调整
- [ ] 终端无法复制文本
- [ ] 鸿蒙 PC 终端无法右键
- [ ] Windows 终端无法选择文本
- [ ] 粘贴多行文本时需让用户确认
- [ ] 连接断开弹窗无法关闭，应改为询问用户是否重连
- [ ] 折叠屏半展开状态下虚拟键盘适配

### 子模块

本仓库通过 git submodule 在 `packages/` 下引入了若干 fork。其中 `xterm` 子模块指向 [AzadKuu/xterm.dart](https://github.com/AzadKuu/xterm.dart)（`ohos` 分支），携带 OHOS IME 适配。克隆后需执行：

```bash
git submodule update --init --recursive
```

## 🆘 帮助

<div align="center">
  <a href="https://qm.qq.com/q/daCGa7eShG"><img alt="qq" src="https://img.shields.io/badge/QQ-群-pink"></a>
  <a href="https://t.me/lpktg"><img alt="donate" src="https://img.shields.io/badge/Telegram-lpktg-green"></a>
  <a href="https://discord.gg/SsVNbRhK7w"><img alt="discord" src="https://img.shields.io/badge/Discord-lpkt-purple"></a>
</div>

- **鸿蒙相关问题**请在本仓库提 issue：[AzadKuu/azad_server_box/issues](https://github.com/AzadKuu/azad_server_box/issues/new)。
- 通用问题也可查阅[上游 wiki](https://github.com/lollipopkit/flutter_server_box/wiki/主页)。
- [ServerBox Monitor](https://github.com/lollipopkit/flutter_server_box/tree/main/monitor) 是安装在你服务器上的 agent，用于推送、桌面小部件、手表 app 及 HTTP 方式访问服务器。安装方法详见其[中文文档](https://github.com/lollipopkit/flutter_server_box/blob/main/monitor/README_zh.md)。

提 issue 前：

1. 请附带完整 log（点击首页右上角），并使用 bug 模版提交。
2. 请先确认问题确实出自本 app，而非服务器或网络。
3. 鸿蒙问题请注明设备类型（`phone` / `tablet` / `2in1`）和鸿蒙系统版本。

## 🧱 贡献

欢迎贡献 —— 尤其是鸿蒙相关的改进。开发环境与 commit 规范见 [CONTRIBUTING.md](CONTRIBUTING.md)。

### 开发

1. 安装 [Flutter](https://flutter.dev/docs/get-started/install) 和 [Rust](https://rustup.rs)。
2. 连同子模块克隆本仓库：`git clone --recursive https://github.com/AzadKuu/azad_server_box.git`
3. 运行 `make deps` 后 `make run` 在非鸿蒙平台启动应用。
4. 鸿蒙平台请按上方[鸿蒙构建](#-鸿蒙构建)步骤操作。
5. 运行 `dart run fl_build -p PLATFORM` 构建指定平台。

### 翻译

- 翻译[指南](https://blog.lpkt.cn/posts/faq/)（上游博客）。欢迎提交 PR。

## 🙏 致谢

本项目 fork 自 **[@lollipopkit](https://github.com/lollipopkit)** 的 **[flutter_server_box](https://github.com/lollipopkit/flutter_server_box)**，感谢原作者及所有贡献者的工作。

本 fork 同样依赖的上游关键库：
- [dartssh2](https://github.com/TerminalStudio/dartssh2) —— SSH 客户端
- [xterm.dart](https://github.com/TerminalStudio/xterm.dart) —— 终端模拟器（已 fork 以适配 OHOS IME）

## 📝 协议

`AGPL v3` —— 继承自上游项目。详见 [LICENSE](LICENSE)。
