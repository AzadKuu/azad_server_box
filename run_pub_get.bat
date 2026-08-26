@echo off
set HTTP_PROXY=http://127.0.0.1:7897
set HTTPS_PROXY=http://127.0.0.1:7897
set FLUTTER_ROOT=D:\workspace\flutter\ohos-flutter_3.44.9
"%FLUTTER_ROOT%\bin\cache\dart-sdk\bin\dart.exe" --packages="%FLUTTER_ROOT%\packages\flutter_tools\.dart_tool\package_config.json" "%FLUTTER_ROOT%\packages\flutter_tools\bin\flutter_tools.dart" pub get
