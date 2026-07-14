Option Explicit
Dim Inst, DNFDB
Set Inst = WScript.CreateObject("WindowsInstaller.Installer")
Set DNFDB = Inst.OpenDatabase(WScript.Arguments(0), 1)
DNFDB.ApplyTransform WScript.Arguments(1), 0
DNFDB.Commit
Set Inst = Nothing
Set DNFDB = Nothing