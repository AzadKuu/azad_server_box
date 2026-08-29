@echo off
setlocal
set CLANG="D:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\native\llvm\bin\clang.exe"
set SYSROOT="D:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\native\sysroot"
set SRC="D:\workspace\azad_server_box\third_party\sqlite3mc_build\sqlite3mc_amalgamation.c"
set OUT="D:\workspace\azad_server_box\third_party\sqlite3mc_build\libsqlite3mc.so"

%CLANG% --target=aarch64-linux-ohos --sysroot=%SYSROOT% -shared -fPIC -O2 ^
  -DSQLITE_ENABLE_FTS5 -DSQLITE_ENABLE_RTREE -DSQLITE_ENABLE_MATH_FUNCTIONS ^
  -DSQLITE_DQS=0 -DSQLITE_DEFAULT_MEMSTATUS=0 -DSQLITE_TEMP_STORE=2 ^
  -DSQLITE_MAX_EXPR_DEPTH=0 -DSQLITE_STRICT_SUBTYPE=1 ^
  -DSQLITE_OMIT_AUTHORIZATION -DSQLITE_OMIT_DECLTYPE -DSQLITE_OMIT_DEPRECATED ^
  -DSQLITE_OMIT_PROGRESS_CALLBACK -DSQLITE_OMIT_SHARED_CACHE ^
  -DSQLITE_OMIT_TCL_VARIABLE -DSQLITE_OMIT_TRACE ^
  -DSQLITE_ENABLE_SESSION -DSQLITE_ENABLE_PREUPDATE_HOOK ^
  -DSQLITE_HAVE_ISNAN -DSQLITE_HAVE_LOCALTIME_R -DSQLITE_HAVE_LOCALTIME_S ^
  -o %OUT% %SRC%

echo Exit code: %ERRORLEVEL%
if exist %OUT% (
  for %%I in (%OUT%) do echo Output size: %%~zI bytes
) else (
  echo Output file not created
)
