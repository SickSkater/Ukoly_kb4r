@echo off
set "REPORT=%USERPROFILE%\Desktop\cim-guest-output.txt"
set "SHARED_REPORT=\\VBOXSVR\CodexCimResults\cim-guest-output.txt"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '\\VBOXSVR\CodexCimStudy\Invoke-LocalGuestCim.ps1' -ExpectedGuestComputerName 'win11' -Confirm:$false" > "%REPORT%" 2>&1
set "RESULT=%ERRORLEVEL%"
copy /Y "%REPORT%" "%SHARED_REPORT%" >nul 2>&1
if errorlevel 1 (
    echo Could not copy output to the shared results folder.
) else (
    echo Shared output: %SHARED_REPORT%
)
type "%REPORT%"
echo.
echo CIM script exit code: %RESULT%
echo Full output: %REPORT%
pause
exit /b %RESULT%
