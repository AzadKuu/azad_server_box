import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:flutter_rust_bridge_hooks/flutter_rust_bridge_hooks.dart';
import 'package:hooks/hooks.dart';

/// Builds `crates/sbm_ffi` and hands the result to the Dart/Flutter SDK as
/// a code asset.
///
/// This replaces cargokit, which drove cargo from a CocoaPods `script_phase` on
/// Apple platforms, a CMake step on Linux and Windows, and a gradle plugin on
/// Android — four integrations, one per platform, and the Apple one had no
/// Swift Package Manager equivalent: a SwiftPM build tool plugin runs in a
/// sandbox that denies writes to the project directory, so cargo cannot write
/// `target/` or `~/.cargo` from one. That mattered because CocoaPods' registry
/// goes read-only on 2026-12-02 and Flutter's fallback to it is removed some
/// time after.
///
/// A build hook sidesteps the question rather than answering it: it is neither
/// a pod nor a Swift package, so it produces no `.podspec` and no
/// `Package.swift`, and the same file covers all five platforms.
void main(List<String> args) async {
  _fixPubCacheOhosSwitch();
  await build(args, (input, output) async {
    try {
      await FlutterRustBridgeNativeAssetsBuilder(
        cratePath: 'crates/sbm_ffi',
        extraCargoEnvironmentVariables: _ohosCargoEnv(input),
      ).run(input: input, output: output);
    } catch (e, s) {
      stderr.writeln('[_fixMissingWindowsDll] builder threw: $e\n$s');
    }

    _replaceSqlite3mcForOhos(input);
    _fixMissingWindowsDll(input);
  });
}

/// Patches Pub Cache packages that have exhaustive switches over
/// TargetPlatform but don't handle TargetPlatform.ohos (added by the
/// HarmonyOS Flutter SDK). Runs the standalone script so the fix is
/// applied before Dart compilation. Idempotent and silent on failure.
void _fixPubCacheOhosSwitch() {
  try {
    final script = '${Directory.current.path}/scripts/fix_ohos_pub_cache.dart';
    if (!File(script).existsSync()) return;
    final dartExe = Platform.executable;
    final result = Process.runSync(dartExe, [script]);
    if (result.exitCode == 0) {
      final out = (result.stdout as String).trim();
      if (out.isNotEmpty) stderr.writeln('[_fixPubCacheOhosSwitch]\n$out');
    }
  } catch (e) {
    stderr.writeln('[_fixPubCacheOhosSwitch] skipped: $e');
  }
}

/// 鸿蒙（OHOS）适配：sqlite3 包的 build hook 会下载预编译的 glibc 二进制
/// (`libsqlite3mc.so`)，它依赖 `ld-linux-aarch64.so.1`，不兼容鸿蒙的 musl libc。
///
/// 这里在构建后扫描共享输出目录和最终输出目录，找到 `libsqlite3mc.so` 并替换为
/// 用鸿蒙 NDK 交叉编译的版本（位于 `third_party/sqlite3mc_build/libsqlite3mc.so`）。
/// 该库只依赖 `libc.so`，兼容鸿蒙。
void _replaceSqlite3mcForOhos(HookInput input) {
  if (!input.config.buildCodeAssets) return;
  final cCompiler = input.config.code.cCompiler;
  if (cCompiler == null) return;
  if (!cCompiler.compiler.toFilePath().toLowerCase().contains('openharmony')) {
    return;
  }

  // 兼容鸿蒙的 libsqlite3mc.so，由鸿蒙 NDK 交叉编译
  final compatibleLib = File(
    '${Directory.current.path}/third_party/sqlite3mc_build/libsqlite3mc.so',
  );
  if (!compatibleLib.existsSync()) return;

  // 收集所有需要扫描的目录
  final dirsToScan = <Directory>[];

  // 1. build hook 共享输出目录
  final sharedDir = Directory(input.outputDirectoryShared.toFilePath());
  if (sharedDir.existsSync()) dirsToScan.add(sharedDir);

  // 2. native_assets 输出目录（install_code_assets 可能在这里放副本）
  final nativeAssetsDir = Directory(
    '${Directory.current.path}/build/native_assets/ohos',
  );
  if (nativeAssetsDir.existsSync()) dirsToScan.add(nativeAssetsDir);

  // 3. ohos entry libs 目录（最终打包进 HAP 的位置）
  final ohosLibsDir = Directory(
    '${Directory.current.path}/ohos/entry/libs',
  );
  if (ohosLibsDir.existsSync()) dirsToScan.add(ohosLibsDir);

  // 4. ohos intermediates 目录
  final ohosIntermediatesDir = Directory(
    '${Directory.current.path}/ohos/entry/build/default/intermediates/libs',
  );
  if (ohosIntermediatesDir.existsSync()) dirsToScan.add(ohosIntermediatesDir);

  int replaced = 0;
  for (final dir in dirsToScan) {
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('libsqlite3mc.so')) continue;
      // 跳过已经是正确版本的文件
      if ((entity as File).lengthSync() == compatibleLib.lengthSync()) continue;
      // 把兼容鸿蒙的库复制到 build hook 输出的位置，覆盖 glibc 二进制
      compatibleLib.copySync(entity.path);
      replaced++;
    }
  }
  if (replaced > 0) {
    stderr.writeln('[_replaceSqlite3mcForOhos] replaced $replaced files');
  }
}

/// Windows 适配：cargo 增量构建不会重新生成被外部删除的输出文件。
///
/// `flutter_rust_bridge_hooks` 在 Windows 上把 cargo 的 `--target-dir` 重定向
/// 到 `%TEMP%\frb_native_assets_<hash>\<hash2>\target\`（避免长路径）。
/// 如果 DLL 被 Temp 清理工具删除，而 cargo fingerprint 没变，cargo 不会重新
/// 链接 `sbm_ffi.dll`，导致 Flutter 报 "file not found" 复制失败。
///
/// 这里在构建后扫描 Temp 输出目录，如果 `sbm_ffi.dll` 缺失但其他构建产物
/// （`sbm_ffi.lib` / `sbm_ffi.d`）存在，说明 cargo 确实运行过只是没重新链接，
/// 就从项目 `target/release/` 复制 DLL 过去。
void _fixMissingWindowsDll(HookInput input) {
  if (!input.config.buildCodeAssets) return;
  if (!Platform.isWindows) return;
  stderr.writeln('[_fixMissingWindowsDll] starting...');

  // 跳过鸿蒙构建（在 Windows 上交叉编译鸿蒙时 Platform.isWindows 也为 true）
  final cCompiler = input.config.code.cCompiler;
  if (cCompiler != null &&
      cCompiler.compiler.toFilePath().toLowerCase().contains('openharmony')) {
    return;
  }

  final sep = Platform.pathSeparator;
  final projectDll = File(
    '${Directory.current.path}${sep}target${sep}release${sep}sbm_ffi.dll',
  );

  // 确保项目 target/release/sbm_ffi.dll 存在；不存在则直接 cargo build
  if (!projectDll.existsSync()) {
    try {
      final result = Process.runSync(
        'cargo',
        ['build', '-p', 'sbm_ffi', '--release'],
        workingDirectory: Directory.current.path,
      );
      if (result.exitCode != 0 || !projectDll.existsSync()) return;
    } catch (_) {
      return; // cargo 不在 PATH 或其他错误，静默跳过
    }
  }

  // 扫描 Temp 目录中的 frb_native_assets_* 目录
  // 结构: %TEMP%/frb_native_assets_<hash>/<hash2>/target/<triple>/release/
  for (final entity in Directory.systemTemp.listSync()) {
    if (entity is! Directory) continue;
    if (!entity.path.contains('frb_native_assets_')) continue;

    // 遍历 hash 子目录（不递归，避免扫描大量 cargo 产物）
    for (final hashDir in (entity as Directory).listSync()) {
      if (hashDir is! Directory) continue;

      final releaseDir = Directory(
        '${hashDir.path}${sep}target${sep}'
        'x86_64-pc-windows-msvc${sep}release',
      );
      if (!releaseDir.existsSync()) continue;

      final dllPath = '${releaseDir.path}${sep}sbm_ffi.dll';
      if (File(dllPath).existsSync()) continue; // DLL 已存在

      // 检查是否有其他构建产物（说明 cargo 确实在此目录运行过）
      final libPath = '${releaseDir.path}${sep}sbm_ffi.lib';
      final dPath = '${releaseDir.path}${sep}sbm_ffi.d';
      if (!File(libPath).existsSync() && !File(dPath).existsSync()) continue;

      // 从项目 target 复制 DLL
      projectDll.copySync(dllPath);
      stderr.writeln(
        '[_fixMissingWindowsDll] copied sbm_ffi.dll to $dllPath',
      );
    }
  }
}

/// 鸿蒙（OHOS）适配：为 `cargo build` 注入环境变量，让 `cc`-rs 用鸿蒙 NDK 的
/// clang 交叉编译 C 依赖（如 `dart-sys`），而不是去找不存在的
/// `aarch64-linux-gnu-gcc`。
///
/// flutter_rust_bridge_hooks 把鸿蒙映射为 `aarch64-unknown-linux-gnu` target，
/// 所以环境变量的 key 用 `aarch64_unknown_linux_gnu`，而 clang 的 `--target`
/// 用 `aarch64-unknown-linux-ohos` 配合鸿蒙 sysroot。
Map<String, String> _ohosCargoEnv(HookInput input) {
  if (!input.config.buildCodeAssets) return const {};
  final cCompiler = input.config.code.cCompiler;
  if (cCompiler == null) return const {};
  final compilerPath = cCompiler.compiler.toFilePath();
  if (!compilerPath.toLowerCase().contains('openharmony')) return const {};
  // llvm/bin -> llvm -> native
  final nativeDir = File(compilerPath).parent.parent.parent;
  final sysroot = '${nativeDir.path}/sysroot';
  if (!Directory(sysroot).existsSync()) return const {};
  final arPath = cCompiler.archiver.toFilePath();
  final archName = input.config.code.targetArchitecture.name;
  final targetTriple = switch (archName) {
    'arm64' => 'aarch64-unknown-linux-ohos',
    'x64' => 'x86_64-unknown-linux-ohos',
    _ => null,
  };
  if (targetTriple == null) return const {};
  final envArch = archName == 'arm64'
      ? 'aarch64_unknown_linux_gnu'
      : 'x86_64_unknown_linux_gnu';
  // 链接阶段：CFLAGS 只影响 cc-rs 的编译，不影响 rustc 的链接。rustc 直接调用
  // LINKER 指定的程序并传递 -Wl 参数，但不传 --target/--sysroot。clang 不知道
  // 目标平台就找不到底层链接器 (ld.lld)，报 "program not executable"。
  // 解决方案：创建 wrapper batch 脚本，自动加上 --target 和 --sysroot。
  final wrapperDir =
      Directory('${Directory.current.path}/.dart_tool/ohos_wrapper');
  wrapperDir.createSync(recursive: true);
  final wrapperPath = '${wrapperDir.path}\\ohos_linker_$archName.bat';

  // rustc 为 aarch64-unknown-linux-gnu target 默认链接 -lgcc_s，但鸿蒙用 musl/clang，
  // sysroot 里没有 libgcc_s（GCC 辅助库，clang 用 compiler-rt 替代）。
  // 创建空 stub 库让链接器找到它但不引入任何符号。
  final stubDir = Directory('${wrapperDir.path}\\stubs');
  stubDir.createSync(recursive: true);
  final stubLibPath = '${stubDir.path}\\libgcc_s.a';
  if (!File(stubLibPath).existsSync()) {
    Process.runSync(arPath, ['rcs', stubLibPath]);
  }

  // Rust std 使用 unwind panic 策略，生成的代码调用 _Unwind_Resume。
  // 鸿蒙 sysroot 没有这个符号，但 NDK 的 llvm/lib/<triple>/libunwind.a 提供了它。
  // 静态链接到 libsbm_ffi.so 中，在 %* 之后让链接器解析未定义符号。
  // targetTriple 是 aarch64-unknown-linux-ohos，目录名是 aarch64-linux-ohos。
  final ohosTriple = targetTriple.replaceAll('-unknown-', '-');
  final llvmLibDir = '${nativeDir.path}/llvm/lib/$ohosTriple';

  File(wrapperPath).writeAsStringSync(
    '@echo off\r\n'
    '"$compilerPath" --target=$targetTriple --sysroot="$sysroot" '
    '-L"${stubDir.path}" -L"$llvmLibDir" %* -lunwind\r\n',
  );

  return {
    'CC_$envArch': compilerPath,
    // cc-rs 默认按空格分割 CFLAGS，路径中的空格（"Program Files"）会被拆碎。
    // 设置 CC_SHELL_ESCAPED_FLAGS=1 让 cc-rs 用 shlex 解析，再用单引号包裹
    // --sysroot 路径。单引号在 shlex 中保持字面值，不处理反斜杠转义。
    'CC_SHELL_ESCAPED_FLAGS': '1',
    'CFLAGS_$envArch': "--target=$targetTriple '--sysroot=$sysroot'",
    'AR_$envArch': arPath,
    'CARGO_TARGET_${envArch.toUpperCase()}_LINKER': wrapperPath,
  };
}
