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
  await build(args, (input, output) async {
    await FlutterRustBridgeNativeAssetsBuilder(
      cratePath: 'crates/sbm_ffi',
      extraCargoEnvironmentVariables: _ohosCargoEnv(input),
    ).run(input: input, output: output);

    _replaceSqlite3mcForOhos(input);
  });
}

/// 鸿蒙（OHOS）适配：sqlite3 包的 build hook 会下载预编译的 glibc 二进制
/// (`libsqlite3mc.so`)，它依赖 `ld-linux-aarch64.so.1`，不兼容鸿蒙的 musl libc。
///
/// 这里在构建后扫描共享输出目录，找到 `libsqlite3mc.so` 并替换为用鸿蒙 NDK
/// 交叉编译的版本（位于 `third_party/sqlite3mc_build/libsqlite3mc.so`）。
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

  // 扫描共享输出目录，替换所有 libsqlite3mc.so
  final sharedDir = Directory(input.outputDirectoryShared.toFilePath());
  if (!sharedDir.existsSync()) return;

  for (final entity in sharedDir.listSync(recursive: true)) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('libsqlite3mc.so')) continue;
    // 把兼容鸿蒙的库复制到 build hook 输出的位置，覆盖 glibc 二进制
    compatibleLib.copySync(entity.path);
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
