@echo off
set FLUTTER_ROOT=D:\workspace\flutter\ohos-flutter_3.44.9
set dart=%FLUTTER_ROOT%\bin\cache\dart-sdk\bin\dart.exe
set snapshot=%FLUTTER_ROOT%\bin\cache\flutter_tools.snapshot
set packages=%FLUTTER_ROOT%\packages\flutter_tools\.dart_tool\package_config.json
set script=%FLUTTER_ROOT%\packages\flutter_tools\bin\flutter_tools.dart

cd /d "%FLUTTER_ROOT%\packages\flutter_tools"
"%dart%" --snapshot="%snapshot%" --snapshot-kind="app-jit" --packages="%packages%" --no-enable-mirrors "%script%"
echo Exit code: %ERRORLEVEL%
