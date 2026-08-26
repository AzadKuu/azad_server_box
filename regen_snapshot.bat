@echo off
set FLUTTER_ROOT=D:\workspace\flutter\ohos-flutter_3.44.9
set dart=%FLUTTER_ROOT%\bin\cache\dart-sdk\bin\dart.exe
set snapshot=%FLUTTER_ROOT%\bin\cache\flutter_tools.snapshot
set packages=%FLUTTER_ROOT%\packages\flutter_tools\.dart_tool\package_config.json
set script=%FLUTTER_ROOT%\packages\flutter_tools\bin\flutter_tools.dart
set stamp=%FLUTTER_ROOT%\bin\cache\flutter_tools.stamp

echo Deleting old snapshot...
if exist "%snapshot%" del "%snapshot%"
if exist "%stamp%" del "%stamp%"

echo Regenerating snapshot...
cd /d "%FLUTTER_ROOT%\packages\flutter_tools"
"%dart%" --verbosity=error --snapshot="%snapshot%" --snapshot-kind="app-jit" --packages="%packages%" --no-enable-mirrors "%script%"
if %ERRORLEVEL% NEQ 0 (
    echo Error: Failed to create snapshot. Exit code: %ERRORLEVEL%
    exit /b 1
)

echo Writing stamp...
>"%stamp%" echo "d8d3344605576535fc8a618ae0cd17f1eed21b94:"

echo Done! Snapshot regenerated successfully.
