VERSION 5.00
Begin VB.Form Form1 
   Caption         =   "UHF test"
   ClientHeight    =   6900
   ClientLeft      =   60
   ClientTop       =   345
   ClientWidth     =   6600
   BeginProperty Font 
      Name            =   "ËÎÌå"
      Size            =   9
      Charset         =   134
      Weight          =   700
      Underline       =   0   'False
      Italic          =   0   'False
      Strikethrough   =   0   'False
   EndProperty
   LinkTopic       =   "Form1"
   MaxButton       =   0   'False
   ScaleHeight     =   6900
   ScaleWidth      =   6600
   StartUpPosition =   2  'CenterScreen
   WhatsThisHelp   =   -1  'True
   Begin VB.ListBox List1 
      BackColor       =   &H00FFFFFF&
      BeginProperty Font 
         Name            =   "ËÎÌå"
         Size            =   12
         Charset         =   134
         Weight          =   700
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   4380
      Left            =   360
      TabIndex        =   1
      Top             =   1440
      Width           =   5895
   End
   Begin VB.CommandButton Command1 
      Caption         =   "Test"
      BeginProperty Font 
         Name            =   "ËÎÌå"
         Size            =   12
         Charset         =   134
         Weight          =   700
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   420
      Left            =   360
      TabIndex        =   0
      Top             =   600
      Width           =   1455
   End
End
Attribute VB_Name = "Form1"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Explicit

Dim databuff32(33) As Byte
Dim bufDataW(33) As Byte



Private Sub Command1_Click()

Dim infoType As Byte
Dim address As Integer
Dim length As Integer
Dim strRead As String
bufDataW(0) = &H31
bufDataW(1) = &H31
bufDataW(2) = &H32
bufDataW(3) = &H32
bufDataW(4) = &H33
bufDataW(5) = &H33
bufDataW(6) = &H34
bufDataW(7) = &H34
bufDataW(8) = &H35
bufDataW(9) = &H35
bufDataW(10) = &H36
bufDataW(11) = &H36
bufDataW(12) = &H37
bufDataW(13) = &H37
bufDataW(14) = &H38
bufDataW(15) = &H38
bufDataW(16) = &H39
bufDataW(17) = &H39
bufDataW(18) = &H30
bufDataW(19) = &H30
bufDataW(20) = &H41
bufDataW(21) = &H41
bufDataW(22) = &H42
bufDataW(23) = &H42
bufDataW(24) = &H0



'connect reader
icdev = uhf_connect(100, 115200) '100->USB port, other value serial port; 115200->serial port baud rate
  
If icdev < 0 Then
  List1.AddItem ("Connect reader failed!")
Else
List1.AddItem ("Connect reader ok!")
End If


'read EPC
infoType = 1 '1£ºEPC£¬2£ºTIP£¬3£ºUSER£¬0£ºreserved
address = 0
length = 8 'will get 32 bytes data

st = uhf_read(ByVal icdev, infoType, address, length, databuff32(0))
If st <> 0 Then
     List1.AddItem "read EPC Error!"
     uhf_disconnect (icdev) 'disconnect reader
     Exit Sub

End If
List1.AddItem "Read EPC OK:"
strRead = StrConv(databuff32, vbUnicode)
List1.AddItem strRead


'read TID
infoType = 2 '1£ºEPC£¬2£ºTIP£¬3£ºUSER£¬0£ºreserved
address = 0
length = 8 'will get 32 bytes data
st = uhf_read(ByVal icdev, infoType, address, length, databuff32(0))
If st <> 0 Then
     List1.AddItem "read TID Error!"
     uhf_disconnect (icdev) 'disconnect reader
     Exit Sub

End If
List1.AddItem "Read TID OK:"
strRead = StrConv(databuff32, vbUnicode)
List1.AddItem strRead


'read USER
infoType = 3 '1£ºEPC£¬2£ºTIP£¬3£ºUSER£¬0£ºreserved
address = 0
length = 8 'will get 32 bytes data
st = uhf_read(ByVal icdev, infoType, address, length, databuff32(0))
If st <> 0 Then
     List1.AddItem "read USER Error!"
     uhf_disconnect (icdev) 'disconnect reader
     Exit Sub

End If
List1.AddItem "Read USER OK:"
strRead = StrConv(databuff32, vbUnicode)
List1.AddItem strRead


'read reserved
infoType = 0 '1£ºEPC£¬2£ºTIP£¬3£ºUSER£¬0£ºreserved
address = 0
length = 4 'will get 32 bytes data
st = uhf_read(ByVal icdev, infoType, address, length, databuff32(0))
If st <> 0 Then
     List1.AddItem "read reserved Error!"
     uhf_disconnect (icdev) 'disconnect reader
     Exit Sub

End If
List1.AddItem "Read reserved OK:"
strRead = StrConv(databuff32, vbUnicode)
List1.AddItem strRead


'reader action
'action:  beep:0x01, red led on:0x02, green led on:0x04, yellow led on:0x08
'time: Unit:10ms
st = uhf_action(ByVal icdev, 5, 50) '(0x01 | 0x04))beep and green led on 500ms
If st <> 0 Then
     List1.AddItem "Reader action Error!"
     uhf_disconnect (icdev) 'disconnect reader
     Exit Sub

End If
List1.AddItem "Reader action OK!"

'write EPC
'infoType = 1 '1£ºEPC£¬2£ºTIP£¬3£ºUSER£¬0£ºreserved
'address = 2
'length = 6 'will get 24 bytes data
'
'st = uhf_write(ByVal icdev, infoType, address, length, bufDataW(0))
'If st <> 0 Then
'     List1.AddItem "write EPC Error!"
'     uhf_disconnect (icdev) 'disconnect reader
'     Exit Sub
'
'End If
'List1.AddItem "write EPC OK:"
'strRead = StrConv(bufDataW, vbUnicode)
'List1.AddItem strRead

'write USER
'infoType = 3 '1£ºEPC£¬2£ºTIP£¬3£ºUSER£¬0£ºreserved
'address = 0
'length = 4 'will write 16 bytes data
'st = uhf_write(ByVal icdev, infoType, address, length, bufDataW(0))
'If st <> 0 Then
'     List1.AddItem "write USER Error!"
'     uhf_disconnect (icdev) 'disconnect reader
'     Exit Sub
'
'End If
'
'bufDataW(16) = &H0
'List1.AddItem "write USER OK:"
'strRead = StrConv(bufDataW, vbUnicode)
'List1.AddItem strRead

'write reserved
'infoType = 0 '1£ºEPC£¬2£ºTIP£¬3£ºUSER£¬0£ºreserved
'address = 0
'length = 4 'will write 16 bytes data
'st = uhf_write(ByVal icdev, infoType, address, length, bufDataW(0))
'If st <> 0 Then
'     List1.AddItem "write reserved Error!"
'     uhf_disconnect (icdev) 'disconnect reader
'     Exit Sub
'
'End If
'List1.AddItem "write reserved OK:"
'strRead = StrConv(bufDataW, vbUnicode)
'List1.AddItem strRead


uhf_disconnect (icdev) 'disconnect reader
List1.AddItem "Disconnect reader!"


End Sub
Private Sub Form_Load()

icdev = -1

End Sub

Private Sub Form_Unload(Cancel As Integer)
quit
End Sub

