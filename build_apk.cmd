@echo off
REM Android release APK 构建脚本（在沙箱外运行，Kotlin daemon 需写 AppData\Local\kotlin）
set "JAVA_HOME=C:\Program Files\Java\jdk-17"
set "ANDROID_HOME=D:\traeproj\JZproject\.tools\android-sdk"
set "ANDROID_SDK_ROOT=D:\traeproj\JZproject\.tools\android-sdk"
set "PUB_CACHE=D:\traeproj\JZproject\.tools\pub-cache"
set "PATH=D:\traeproj\JZproject\.tools\flutter\bin;%JAVA_HOME%\bin;%ANDROID_HOME%\platform-tools;%PATH%"
cd /d D:\traeproj\JZproject\mobile
call flutter.bat build apk --release
echo BUILD_EXIT: %ERRORLEVEL%
