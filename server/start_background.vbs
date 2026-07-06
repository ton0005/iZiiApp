Set WshShell = CreateObject("WScript.Shell")
' Run file bat (WindowStyle = 0)
WshShell.Run "cmd.exe /c run_server.bat", 0, False
