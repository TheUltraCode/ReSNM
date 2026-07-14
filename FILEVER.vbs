Option Explicit
Dim obj
Set obj = CreateObject("Scripting.FileSystemObject")
WScript.Echo obj.GetFileVersion(WScript.Arguments(0))
Set obj = Nothing