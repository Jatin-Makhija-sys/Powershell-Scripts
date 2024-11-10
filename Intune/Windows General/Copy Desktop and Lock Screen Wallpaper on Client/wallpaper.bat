@ECHO OFF
set wallpaper=C:\wallpaper
set desktopCopyFrom=\\corp.techpress.net\SYSVOL\corp.techpress.net\scripts\Desktop-wallpaper.jpg
set lockscreenCopyFrom=\\corp.techpress.net\SYSVOL\corp.techpress.net\scripts\Lock-screen-background.jpg

REM Ensure the folder exists
IF NOT EXIST "%wallpaper%" (
    MKDIR %wallpaper%
)

REM Always copy the desktop wallpaper, overwriting the existing file
xcopy "%desktopCopyFrom%" "%wallpaper%" /k/y

REM Always copy the lock screen wallpaper, overwriting the existing file
xcopy "%lockscreenCopyFrom%" "%wallpaper%" /k/y