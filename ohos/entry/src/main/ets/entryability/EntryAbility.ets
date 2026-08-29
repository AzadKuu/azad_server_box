
import { FlutterAbility, FlutterEngine, MethodChannel, MethodCall, MethodResult, Log } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import dataPreferences from '@ohos.data.preferences';
import inputMethod from '@ohos.inputMethod';
import deviceInfo from '@ohos.deviceInfo';
import i18n from '@ohos.i18n';
import pasteboard from '@ohos.pasteboard';
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import common from '@ohos.app.ability.common';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';

const TAG = "EntryAbility";

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)
    this.registerPathProvider(flutterEngine)
    this.registerSharedPreferences(flutterEngine)
    this.registerImeHandler(flutterEngine)
    this.registerLocaleHandler(flutterEngine)
    this.registerClipboardHandler(flutterEngine)
    this.registerFilePickerHandler(flutterEngine)
  }

  /**
   * 鸿蒙软键盘退格键处理。
   *
   * 问题：Flutter 的 CustomTextEdit 在 deleteDetection=false 时初始编辑状态为空
   * （选区 0,0），鸿蒙 TextInputPlugin.handleDeleteEvent 在 start==0&&end==0 时
   * 直接返回不通知 Flutter，导致终端退格键无响应。
   *
   * 方案：在 ArkTS 层面监听 inputMethodController 的 deleteLeft 事件，通过
   * MethodChannel `azad/ime` 通知 Flutter。Flutter 端只在终端获得焦点时处理。
   *
   * 仅对手机/平板启用（PC/2in1 有物理键盘，退格键通过 KeyEvent 处理）。
   * 同时通过 MethodChannel `azad/device_info` 把设备类型传入 Flutter。
   */
  private registerImeHandler(flutterEngine: FlutterEngine): void {
    const messenger = flutterEngine.dartExecutor.getBinaryMessenger();
    const dt = deviceInfo.deviceType;
    // 注意：2in1 必须包含在 isMobile 内——鸿蒙 PC/2in1 在平板模式或触屏使用
    // 时同样会弹出软键盘，退格键同样依赖本 handler 兜底，不能排除。
    const isMobile = dt === 'phone' || dt === 'tablet' || dt === '2in1';
    Log.i(TAG, "OHOS_DEV deviceType=" + dt + " isMobile=" + isMobile);

    // 把设备类型传入 Flutter
    const deviceInfoChannel = new MethodChannel(messenger, 'azad/device_info');
    deviceInfoChannel.setMethodCallHandler({
      onMethodCall(call: MethodCall, result: MethodResult) {
        if (call.method === 'isMobile') {
          result.success(isMobile);
        } else if (call.method === 'deviceType') {
          result.success(dt);
        } else {
          result.notImplemented();
        }
      }
    });

    if (!isMobile) {
      Log.i(TAG, "IME backspace handler skipped (not mobile device)");
      return;
    }

    // 监听退格键事件，通知 Flutter
    const imeChannel = new MethodChannel(messenger, 'azad/ime');
    const controller = inputMethod.getController();
    try {
      controller.on('deleteLeft', (length: number) => {
        Log.i(TAG, "OHOS_BS ArkTS deleteLeft event: length=" + length);
        imeChannel.invokeMethod('deleteLeft', length);
      });
      Log.i(TAG, "IME backspace handler registered");
    } catch (err) {
      Log.e(TAG, "Failed to register IME backspace handler: " + JSON.stringify(err));
    }
  }

  /**
   * 把鸿蒙系统偏好语言通过 MethodChannel `azad/locale` 暴露给 Flutter。
   *
   * 首次启动时 Flutter 侧 Stores.setting.locale 为空，会通过此 channel
   * 请求 i18n.getAppPreferredLanguage()（如 "zh-Hans-CN"），转换后存入
   * setting，使首启语言与系统一致而非默认英语。
   */
  private registerLocaleHandler(flutterEngine: FlutterEngine): void {
    const messenger = flutterEngine.dartExecutor.getBinaryMessenger();
    const channel = new MethodChannel(messenger, 'azad/locale');
    channel.setMethodCallHandler({
      onMethodCall(call: MethodCall, result: MethodResult) {
        if (call.method === 'getPreferredLanguage') {
          try {
            const lang: string = i18n.System.getAppPreferredLanguage();
            Log.i(TAG, "OHOS preferred language: " + lang);
            result.success(lang);
          } catch (err) {
            Log.e(TAG, "Failed to get preferred language: " + JSON.stringify(err));
            result.success(null);
          }
        } else {
          result.notImplemented();
        }
      }
    });
    Log.i(TAG, "locale channel registered");
  }

  /**
   * 鸿蒙剪贴板读取，按官方文档走 READ_PASTEBOARD 动态授权流程：
   * 1. hasData 判断剪贴板是否有数据（避免无效弹窗）
   * 2. requestPermissionsFromUser 动态申请 READ_PASTEBOARD 权限
   * 3. 授权成功后 getData 读取
   *
   * 注意：READ_PASTEBOARD 是 user_grant（用户授权）权限，必须在 module.json5
   * 声明（reason + usedScene），且通过 requestPermissionsFromUser 运行时弹窗
   * 申请；不能依赖安装时静默授权。AGC 侧需申请含该权限的 Profile。
   */
  private registerClipboardHandler(flutterEngine: FlutterEngine): void {
    const messenger = flutterEngine.dartExecutor.getBinaryMessenger();
    const channel = new MethodChannel(messenger, 'azad/clipboard');
    // 缓存外层 this（EntryAbility 实例），因为 onMethodCall 是对象方法，
    // 其内部的 this 不指向 EntryAbility。
    const host = this;
    channel.setMethodCallHandler({
      onMethodCall(call: MethodCall, result: MethodResult) {
        if (call.method === 'getData') {
          const context = host.context as common.UIAbilityContext;
          if (context == null) {
            Log.e(TAG, "OHOS clipboard: context is null");
            result.success(null);
            return;
          }
          host.readClipboardWithPermission(context).then((text: string | null) => {
            Log.i(TAG, "OHOS clipboard getData ok, len=" + (text ? text.length : -1));
            result.success(text);
          }).catch((err: Error) => {
            Log.e(TAG, "OHOS clipboard getData error: " + JSON.stringify(err));
            result.success(null);
          });
        } else {
          result.notImplemented();
        }
      }
    });
    Log.i(TAG, "clipboard channel registered");
  }

  /**
   * 带动态权限申请地读取剪贴板文本。
   */
  private async readClipboardWithPermission(context: common.UIAbilityContext): Promise<string | null> {
    const systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
    // 1. 剪贴板无数据则无需申请权限
    let hasData: boolean = false;
    try {
      hasData = await systemPasteboard.hasData();
    } catch (err) {
      Log.e(TAG, "OHOS clipboard hasData error: " + JSON.stringify(err));
      return null;
    }
    if (!hasData) {
      Log.i(TAG, "OHOS clipboard: no data, skip permission");
      return null;
    }

    // 2. 动态申请 READ_PASTEBOARD 权限
    const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    const permissions: Array<Permissions> = ['ohos.permission.READ_PASTEBOARD'];
    let granted: boolean = false;
    try {
      const res = await atManager.requestPermissionsFromUser(context, permissions);
      const authResults: Array<number> = res.authResults;
      for (let i = 0; i < authResults.length; i++) {
        if (authResults[i] === 0) {
          granted = true;
          break;
        }
      }
    } catch (err) {
      Log.e(TAG, "OHOS clipboard requestPermissionsFromUser error: " + JSON.stringify(err));
      return null;
    }
    if (!granted) {
      Log.e(TAG, "OHOS clipboard: user denied READ_PASTEBOARD");
      return null;
    }

    // 3. 授权成功后读取
    try {
      const data: pasteboard.PasteData = await systemPasteboard.getData();
      return data.getPrimaryText();
    } catch (err) {
      Log.e(TAG, "OHOS clipboard getData error: " + JSON.stringify(err));
      return null;
    }
  }

  /**
   * 实现 path_provider 插件的 method channel（plugins.flutter.io/path_provider）。
   *
   * 标准 path_provider 插件没有鸿蒙原生实现，若不注册此 handler，Dart 侧
   * getApplicationDocumentsDirectory() 等会抛 MissingPluginException，
   * 导致 Paths.init() 失败白屏。
   */
  private registerPathProvider(flutterEngine: FlutterEngine): void {
    const context = this.context;
    const messenger = flutterEngine.dartExecutor.getBinaryMessenger();
    const channel = new MethodChannel(messenger, 'plugins.flutter.io/path_provider');
    channel.setMethodCallHandler({
      onMethodCall(call: MethodCall, result: MethodResult) {
        Log.i(TAG, "path_provider method: " + call.method);
        switch (call.method) {
          case 'getApplicationSupportDirectory':
            result.success(context.filesDir);
            break;
          case 'getApplicationCacheDirectory':
            result.success(context.cacheDir);
            break;
          case 'getTemporaryDirectory':
            result.success(context.tempDir);
            break;
          case 'getApplicationDocumentsDirectory':
            result.success(context.filesDir);
            break;
          case 'getLibraryDirectory':
            result.success(context.filesDir);
            break;
          case 'getStorageDirectory':
          case 'getExternalCacheDirectories':
          case 'getExternalStorageDirectories':
          case 'getDownloadsDirectory':
            result.success(null);
            break;
          default:
            result.notImplemented();
            break;
        }
      }
    });
    Log.i(TAG, "path_provider channel registered");
  }

  /**
   * 实现 shared_preferences 插件的 method channel（plugins.flutter.io/shared_preferences）。
   *
   * 标准 shared_preferences 插件没有鸿蒙原生实现，用 @ohos.data.preferences 持久化。
   * 方法：getAllWithParameters, setBool, setInt, setDouble, setString, setStringList,
   *       remove, clear, clearWithParameters, getAll
   */
  private registerSharedPreferences(flutterEngine: FlutterEngine): void {
    const context = this.context;
    const messenger = flutterEngine.dartExecutor.getBinaryMessenger();
    const channel = new MethodChannel(messenger, 'plugins.flutter.io/shared_preferences');
    const PREF_NAME = 'flutter_shared_preferences';

    channel.setMethodCallHandler({
      onMethodCall(call: MethodCall, result: MethodResult) {
        Log.i(TAG, "shared_preferences method: " + call.method);
        dataPreferences.getPreferences(context, PREF_NAME).then((prefs) => {
          switch (call.method) {
            case 'getAll':
            case 'getAllWithParameters': {
              // 返回所有键值对（忽略 prefix/allowList 过滤，Dart 侧会自行过滤）
              const all = prefs.getAllSync();
              result.success(all);
              break;
            }
            case 'setBool': {
              const key: string = call.argument('key');
              const value: boolean = call.argument('value');
              prefs.putSync(key, value);
              prefs.flushSync();
              result.success(true);
              break;
            }
            case 'setInt':
            case 'setDouble': {
              const key: string = call.argument('key');
              const value: number = call.argument('value');
              prefs.putSync(key, value);
              prefs.flushSync();
              result.success(true);
              break;
            }
            case 'setString': {
              const key: string = call.argument('key');
              const value: string = call.argument('value');
              prefs.putSync(key, value);
              prefs.flushSync();
              result.success(true);
              break;
            }
            case 'setStringList': {
              const key: string = call.argument('key');
              const value: Array<string> = call.argument('value');
              prefs.putSync(key, value);
              prefs.flushSync();
              result.success(true);
              break;
            }
            case 'remove': {
              const key: string = call.argument('key');
              prefs.deleteSync(key);
              prefs.flushSync();
              result.success(true);
              break;
            }
            case 'clear':
            case 'clearWithParameters': {
              prefs.clearSync();
              prefs.flushSync();
              result.success(true);
              break;
            }
            default:
              result.notImplemented();
              break;
          }
        }).catch((err: Error) => {
          Log.e(TAG, "shared_preferences error: " + JSON.stringify(err));
          result.success(null);
        });
      }
    });
    Log.i(TAG, "shared_preferences channel registered");
  }

  /**
   * 实现 azad/file_picker channel。
   *
   * file_picker 插件无鸿蒙实现，用 @ohos.file.picker 的 DocumentViewPicker 桥接：
   * - pickFilePath: select() 选文件，复制到 cacheDir，返回沙箱路径（上传用）
   * - saveFilePath: save() 选保存位置，返回 URI（下载用）
   * - copyToUri: 把本地沙箱文件复制到 URI（下载完成后用）
   */
  private registerFilePickerHandler(flutterEngine: FlutterEngine): void {
    const context = this.context;
    const messenger = flutterEngine.dartExecutor.getBinaryMessenger();
    const channel = new MethodChannel(messenger, 'azad/file_picker');
    channel.setMethodCallHandler({
      onMethodCall(call: MethodCall, result: MethodResult) {
        switch (call.method) {
          case 'pickFilePath': {
            const documentPicker = new picker.DocumentViewPicker(context);
            const options = new picker.DocumentSelectOptions();
            documentPicker.select(options).then((uris: Array<string>) => {
              if (uris == null || uris.length == 0) {
                result.success(null);
                return;
              }
              try {
                const uri = uris[0];
                let name = uri.substring(uri.lastIndexOf('/') + 1);
                try {
                  name = decodeURIComponent(name);
                } catch (e) {
                  // ignore decode error
                }
                const destPath = context.cacheDir + '/' + name;
                const srcFile = fs.openSync(uri, fs.OpenMode.READ_ONLY);
                fs.copyFileSync(srcFile.fd, destPath);
                fs.closeSync(srcFile);
                Log.i(TAG, "pickFilePath copied to " + destPath);
                result.success(destPath);
              } catch (e) {
                Log.e(TAG, "pickFilePath copy failed: " + JSON.stringify(e));
                result.success(null);
              }
            }).catch((err: Error) => {
              Log.i(TAG, "pickFilePath cancelled: " + JSON.stringify(err));
              result.success(null);
            });
            break;
          }
          case 'pickFilePaths': {
            const documentPicker = new picker.DocumentViewPicker(context);
            const options = new picker.DocumentSelectOptions();
            options.maxSelectNumber = 100;
            documentPicker.select(options).then((uris: Array<string>) => {
              if (uris == null || uris.length == 0) {
                result.success(null);
                return;
              }
              try {
                const paths: Array<string> = [];
                for (let i = 0; i < uris.length; i++) {
                  const uri = uris[i];
                  let name = uri.substring(uri.lastIndexOf('/') + 1);
                  try {
                    name = decodeURIComponent(name);
                  } catch (e) {
                    // ignore decode error
                  }
                  const destPath = context.cacheDir + '/' + name;
                  const srcFile = fs.openSync(uri, fs.OpenMode.READ_ONLY);
                  fs.copyFileSync(srcFile.fd, destPath);
                  fs.closeSync(srcFile);
                  paths.push(destPath);
                }
                Log.i(TAG, "pickFilePaths copied " + paths.length + " files");
                result.success(paths);
              } catch (e) {
                Log.e(TAG, "pickFilePaths copy failed: " + JSON.stringify(e));
                result.success(null);
              }
            }).catch((err: Error) => {
              Log.i(TAG, "pickFilePaths cancelled: " + JSON.stringify(err));
              result.success(null);
            });
            break;
          }
          case 'saveFilePath': {
            const fileName: string = call.argument('fileName');
            const documentPicker = new picker.DocumentViewPicker(context);
            const options = new picker.DocumentSaveOptions();
            if (fileName != null && fileName.length > 0) {
              options.newFileNames = [fileName];
            }
            documentPicker.save(options).then((uris: Array<string>) => {
              if (uris == null || uris.length == 0) {
                result.success(null);
                return;
              }
              Log.i(TAG, "saveFilePath -> " + uris[0]);
              result.success(uris[0]);
            }).catch((err: Error) => {
              Log.i(TAG, "saveFilePath cancelled: " + JSON.stringify(err));
              result.success(null);
            });
            break;
          }
          case 'copyToUri': {
            const localPath: string = call.argument('localPath');
            const uri: string = call.argument('uri');
            try {
              const srcFile = fs.openSync(localPath, fs.OpenMode.READ_ONLY);
              const dstFile = fs.openSync(uri, fs.OpenMode.READ_WRITE);
              fs.copyFileSync(srcFile.fd, dstFile.fd);
              fs.closeSync(srcFile);
              fs.closeSync(dstFile);
              Log.i(TAG, "copyToUri " + localPath + " -> " + uri);
              result.success(true);
            } catch (e) {
              Log.e(TAG, "copyToUri failed: " + JSON.stringify(e));
              result.success(false);
            }
            break;
          }
          default:
            result.notImplemented();
            break;
        }
      }
    });
    Log.i(TAG, "azad/file_picker channel registered");
  }
}
