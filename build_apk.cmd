@echo off
REM Android release APK build script (run outside sandbox; Kotlin daemon needs AppData\Local\kotlin)
REM bump_version.ps1 auto-increments build number so new APK installs over old one without uninstall
set "JAVA_HOME=C:\Program Files\Java\jdk-17"
set "ANDROID_HOME=D:\traeproj\JZproject\.tools\android-sdk"
set "ANDROID_SDK_ROOT=D:\traeproj\JZproject\.tools\android-sdk"
set "PUB_CACHE=D:\traeproj\JZproject\.tools\pub-cache"
set "PATH=D:\traeproj\JZproject\.tools\flutter\bin;%JAVA_HOME%\bin;%ANDROID_HOME%\platform-tools;%PATH%"
cd /d D:\traeproj\JZproject\mobile
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\traeproj\JZproject\bump_version.ps1"
call flutter.bat build apk --release
set "BEXIT=%ERRORLEVEL%"
echo BUILD_EXIT: %BEXIT%
exit /b %BEXIT%