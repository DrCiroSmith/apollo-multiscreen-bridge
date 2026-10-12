' Apollo Multi-Screen Bridge - Silent VBS Launcher
' Launches PowerShell supervisor hidden without command prompt flickering.

Set fso = CreateObject("Scripting.FileSystemObject")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
psScript = fso.BuildPath(scriptDir, "launch_and_heal.ps1")

cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & psScript & """"

Set shell = CreateObject("WScript.Shell")
shell.Run cmd, 0, False
