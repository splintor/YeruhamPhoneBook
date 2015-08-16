del c:\Projects\YeruhamPhoneBook\platforms\android\build\outputs\apk\YeruhamPhoneBook.apk

del c:\Projects\YeruhamPhoneBook\platforms\android\build\outputs\apk\android-release-unsigned.apk

call c:\Projects\YeruhamPhoneBook\platforms\android\cordova\build.bat --release

call %java_home%/bin/jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 -keystore "c:\Users\sflint\Documents\Google Drive\splintor.keystore" -storepass datatech c:\Projects\YeruhamPhoneBook\platforms\android\build\outputs\apk\android-release-unsigned.apk splintor

call c:\Projects\android-sdks\build-tools\22.0.1\zipalign.exe -v 4 c:\Projects\YeruhamPhoneBook\platforms\android\build\outputs\apk\android-release-unsigned.apk c:\Projects\YeruhamPhoneBook\platforms\android\build\outputs\apk\YeruhamPhoneBook.apk