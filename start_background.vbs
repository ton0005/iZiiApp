Set WshShell = CreateObject("WScript.Shell")
' Chay file bat o che do an (WindowStyle = 0)
WshShell.Run "cmd.exe /c run_server.bat", 0, False
