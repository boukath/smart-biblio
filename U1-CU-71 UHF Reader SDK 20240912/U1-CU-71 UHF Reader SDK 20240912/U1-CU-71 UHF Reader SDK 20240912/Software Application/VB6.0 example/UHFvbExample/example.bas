Attribute VB_Name = "Module1"
Option Explicit
Global icdev As Long
Global st As Integer


'comm function
Declare Function uhf_connect Lib "E7umf.dll" (ByVal port As Integer, ByVal baud As Long) As Long
Declare Function uhf_disconnect Lib "E7umf.dll" (ByVal icdev As Long) As Integer
Declare Function uhf_read Lib "E7umf.dll" (ByVal icdev As Long, ByVal typ%, ByVal adr%, ByVal rlen%, ByRef sdata As Byte) As Integer
Declare Function uhf_write Lib "E7umf.dll" (ByVal icdev As Long, ByVal typ%, ByVal adr%, ByVal wlen%, ByRef sdata As Byte) As Integer
Declare Function uhf_action Lib "E7umf.dll" (ByVal icdev As Long, ByVal action1 As Byte, ByVal time1 As Byte) As Integer

Sub quit()
    If icdev > 0 Then
       st = uhf_disconnect(icdev)
       icdev = -1
    End If
End Sub


