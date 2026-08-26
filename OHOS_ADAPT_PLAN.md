# AzadServerBox 鸿蒙适配规划

基于 [ServerBox](https://github.com/lollipopkit/flutter_server_box) fork 做鸿蒙（HarmonyOS）适配，适配完再加 AI 协同功能。

## 当前状态

- ✅ ServerBox fork 到 `d:\workspace\azad_server_box`
- ✅ submodule 全部拉取（`git submodule update --init --recursive`）
- ✅ 结构分析完成
- ⏳ **阻塞：等 ohos-flutter 3.44.9 release**（ServerBox 要求 `flutter: ">=3.44.9"` + `sdk: ">=3.11.0"`，当前 ohos-flutter 3.41.10 / Dart 3.11.5 不够，逐个改约束不可持续）

## ohos-flutter 环境要求

- 用 **git clone**（不要 zip 解压，会缺 .git 导致 flutter 拒跑 + 版本检测 0.0.0-unknown）
- 仓库：`https://gitcode.com/openharmony-sig/flutter_flutter.git`
- 等 3.44.9 release 分支出现后：
  ```powershell
  git clone -b <3.44.9-release-分支> --depth 1 https://gitcode.com/openharmony-sig/flutter_flutter.git D:\workspace\flutter\ohos-flutter
  & D:\workspace\flutter\ohos-flutter\bin\flutter.bat --version  # 验证版本号正常显示
  & D:\workspace\flutter\ohos-flutter\bin\flutter.bat precache --ohos --no-universal  # 下鸿蒙引擎
  ```

## ServerBox 结构分析

### packages/（8 个 submodule + webui）

| 包 | 语言 | 鸿蒙适配 |
|---|---|---|
| dartssh2 | 纯 Dart | 无需适配 |
| xterm | 纯 Dart | 无需适配 |
| fl_lib | Dart | 验证 |
| fl_build | Dart | 验证 |
| circle_chart | Dart | 验证 |
| **flutter_pty** | **C**（POSIX PTY: forkpty/openpty） | **需适配**（build hook + native_toolchain_c + ohos NDK，鸿蒙 musl libc 有 forkpty） |
| watch_connectivity | Dart | 降级（鸿蒙无 watchOS） |
| plain_notification_token | Dart | 降级（鸿蒙推送另案） |

### crates/（Rust workspace）

| crate | 用途 | 鸿蒙适配 |
|---|---|---|
| sbm_parser | 状态解析（纯 Rust） | 随 sbm_ffi 编译 |
| sbm_native | 原生 syscall/procfs（仅 monitor） | app 不直接用 |
| **sbm_ffi** | flutter_rust_bridge FFI 绑定 | **需适配**（Rust ohos target 交叉编译） |

### 关键 build hook

- `hook/build.dart`：用 `FlutterRustBridgeNativeAssetsBuilder` 编译 `crates/sbm_ffi`（Rust → 各平台 .so/.dylib）
- `packages/flutter_pty/hook/build.dart`：用 `native_toolchain_c` 编译 C PTY 代码
- `hooks.user_defines.sqlite3.source: sqlite3mc`：sqlite3 加密版编译

## 适配步骤（3.44.9 release 就绪后）

### 1. 基础
```powershell
cd D:\workspace\azad_server_box
$flutter = "D:\workspace\flutter\ohos-flutter\bin\flutter.bat"
& $flutter pub get
& $flutter create --platforms=ohos .   # 生成 ohos/ 工程
```

### 2. sbm_ffi（Rust）鸿蒙交叉编译
- 安装 Rust ohos target（`rustup target add aarch64-unknown-linux-ohos` 或鸿蒙 NDK 的 clang 作 CC）
- `flutter_rust_bridge_hooks` 的 build hook 需识别 ohos 平台，配置 cargo 交叉编译到 `aarch64-unknown-linux-ohos`
- 产物 `libsbm_ffi.so` 打包进 HAP

### 3. flutter_pty（C）鸿蒙适配
- `hook/build.dart` 让 ohos 平台编译 `flutter_pty_unix.c`（鸿蒙 POSIX 兼容）
- native_toolchain_c 用鸿蒙 NDK clang
- 产物 `libflutter_pty.so` 打包

### 4. sqlite3 + sqlite3mc
- build hook 用鸿蒙 NDK 编译 sqlite3mc C 源码
- 产物 `libsqlite3.so` 放 `ohos/entry/src/main/libs/arm64-v8a/`（复用 venera 经验）

### 5. 平台特定包降级
- watch_connectivity / plain_notification_token / wakelock_plus 等：鸿蒙上 stub 实现，避免编译失败

### 6. 跑通
```powershell
& $flutter run -d ohos
```

### 7. 加 AI 协同
- 端侧优先：鸿蒙 `@hms.ai` channel
- 云端增强：用户自配 OpenAI/ClaBaudude/盘古 key
- 安全闸门：危险命令正则拦截 + 人工确认（见 AzadSSH `consts.dart`）
- Agent 模式：上下文采集 → LLM → 命令生成 → 闸门 → 确认 → 执行 → 反馈循环

## 已踩的坑（环境）

| 问题 | 解决 |
|---|---|
| ohos-flutter zip 解压缺 .git | 用 git clone |
| `Flutter SDK version is 0.0.0-unknown` | version/flutter.version.json 带 BOM 或非 git clone；用 git clone release 分支 |
| `precache` 下到 googleapis 失败 | `precache --ohos --no-universal` 只下鸿蒙引擎（走华为 OBS） |
| 鸿蒙白屏 | `WidgetsFlutterBinding.ensureInitialized()` 要在用 MethodChannel 的 path_provider 之前调；显式 `Directory.createSync` 建数据目录；`runZonedGuarded` 捕获异常 |
| 预发布版本号 `3.41.10-ohos-1.0.0` 不满足 `>=3.41.10` | 语义版本预发布 < 正式版，等 3.44.9 release 避免 |

## 参考

- venera 鸿蒙适配经验：`D:\workspace\venera`（.so 打包、ohos_compat、channel 桥接模式）
- AzadSSH P0 脚手架：`D:\workspace\AzadSSH`（环境验证、深色主题、初始化模式）
