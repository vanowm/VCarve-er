#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=../resources/vcarve'er.ico
#AutoIt3Wrapper_Outfile=../bin/VCarve'er_v1.1.0.exe
#AutoIt3Wrapper_UseX64=y
#AutoIt3Wrapper_Compression=4
#AutoIt3Wrapper_UseUpx=y
#AutoIt3Wrapper_Res_Description=VCarve'er
#AutoIt3Wrapper_Res_Field=Comment|VCarve'er - show messages popups as toast notifications
#AutoIt3Wrapper_Res_Fileversion=1.1.0.13
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=y
#AutoIt3Wrapper_Res_ProductVersion=1.1.0
#AutoIt3Wrapper_Res_LegalCopyright=©V@no 2024
#AutoIt3Wrapper_Res_Language=1033
#AutoIt3Wrapper_Res_Field=ProductName|VCarve'er
#AutoIt3Wrapper_Res_Field=BuildDate|%longdate%  %time%
#AutoIt3Wrapper_Run_Tidy=y
#AutoIt3Wrapper_Run_Au3Stripper=y
#Au3Stripper_Parameters=/pe /so /rm /rsln

#AutoIt3Wrapper_Run_Before=cd.>.stop
#AutoIt3Wrapper_Run_Before=cd.>../bin/.stop

#AutoIt3Wrapper_Run_After=del "../bin/VCarve'er.exe"
#AutoIt3Wrapper_Run_After=mklink /h "../bin/VCarve'er.exe" "%out%"
#AutoIt3Wrapper_Run_After=del .stop
#AutoIt3Wrapper_Run_After=del "../bin/.stop"

#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#include <WinAPI.au3>
#include <_debug.au3>
#include <Misc.au3>
#include <ScreenCapture.au3>
#include <UWPOCR.au3>
;~ _UWPOCR_Log(__UWPOCR_Log)
#include <GuiConstants.au3>
#include <TrayConstants.au3>

Global Const $VERSION = "1.1.0.13"
Global Const $TITLE = "VCarve'er v" & $VERSION
Global Const $stopFile = @ScriptDir & "\.stop"
Global Const $imagePath = "dialog.png" ; temporary image file
Global Const $timeout = 10000 ; notification message timeout in milliseconds
Global Const $animationSpeed = 4 ; animation speed 1 = fastest
;~ Global Const $class = "[CLASS:#32770; TITLE:VCarve Pro]"
Global Const $button1 = "[CLASS:Button; INSTANCE:1]"
Global Const $button2 = "[CLASS:Button; INSTANCE:2]"
Global Const $posOut = -999999999999999999 ;move message box outside visible area
Global Const $hToast = GUICreate("", 0, 0, -1, -1, BitOR($WS_POPUP, $WS_BORDER), BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))
Global Const $idPic = GUICtrlCreatePic('', 0, 0, 0, 0)
Global Const $hPic = GUICtrlGetHandle($idPic)
Global Const $hUser32_Dll = DllOpen("user32.dll")
Global $iniSection = "Settings"
Global $popupTime
Global $posWidthDest
Global $posWidthDestPrev
Global $posWidth
Global $posLeft
Global $posTop
Global $posHeight
Global $speed
Global $step
Global $sText
Global $iRight
Local $hwnd
Local $prevHwnd
Local $name = StringLeft(@ScriptName, StringInStr(@ScriptName, ".", 2, -1) - 1)
Local $name2 = StringRegExpReplace($name, "[\s_-]+v[0-9]+.*", "")
Global $ini = @ScriptDir & "\" & $name & ".ini"
Local $ini2 = @ScriptDir & "\" & $name2 & ".ini"

Local $iniExists = BitOR(FileExists($ini) ? 1 : 0, FileExists($ini2) ? 2 : 0)
If $iniExists = 2 Or Not $iniExists Then $ini = $ini2
Global $settingType = Number(IniRead($ini, $iniSection, "type", 1)) ; 0 = default popup; 1 = image; 2 = toast/balloon; 3 = none
Global $settingMove = Number(IniRead($ini, $iniSection, "move", 1)) ; move popup to cursor position
Global $settingAutoStart = Number(IniRead($ini, $iniSection, "autoStart", 1)) ; auto start with Windows



If _Singleton("VCarve'er", 1) = 0 Then
	Exit
EndIf

Opt("WinTitleMatchMode", 3)
Opt('TrayAutoPause', 0)
Opt("TrayMenuMode", 7) ; Default tray menu items will not be shown and must be explicitly added
Opt("TrayOnEventMode", 1) ; Enable TrayOnEventMode.

OnAutoItExitRegister("_exit")
TraySetToolTip($TITLE)
TrayCreateItem($TITLE)
TrayItemSetState(-1, $TRAY_DISABLE)
TrayCreateItem("")
Global $trayType = TrayCreateMenu("Notification type")
Global $trayType0 = TrayCreateItem("Default", $trayType, -1, 1)
TrayItemSetOnEvent(-1, "TrayEvent")
Global $trayType1 = TrayCreateItem("Image", $trayType, -1, 1)
TrayItemSetOnEvent(-1, "TrayEvent")
Global $trayType2 = TrayCreateItem("System", $trayType, -1, 1)
TrayItemSetOnEvent(-1, "TrayEvent")
Global $trayType3 = TrayCreateItem("None", $trayType, -1, 1)
TrayItemSetOnEvent(-1, "TrayEvent")
Global $trayMove = TrayCreateItem("Move popups")
TrayItemSetOnEvent(-1, "TrayEvent")
Global $trayAutoStart = TrayCreateItem("Auto start")
TrayItemSetOnEvent(-1, "TrayEvent")
TrayCreateItem("")
Global $trayLast = TrayCreateItem("Last message")
TrayItemSetOnEvent(-1, "TrayEvent")
TrayCreateItem("")
Global $trayExit = TrayCreateItem("Exit")
TrayItemSetOnEvent(-1, "TrayEvent")
setTray()

Global $hHookFunc = DllCallbackRegister('_WinEventProc', 'none', 'ptr;uint;hwnd;int;int;uint;uint')
Global $hWinHook = _WinAPI_SetWinEventHook($EVENT_OBJECT_CREATE, $EVENT_OBJECT_CREATE, DllCallbackGetPtr($hHookFunc))

While 1
	If FileExists($stopFile) Then
		FileDelete($stopFile)
		ExitLoop
	EndIf
	If $popupTime Then
		If TimerDiff($popupTime) > $timeout Then closePopup()

		If $posWidth <> $posWidthDest Then

			$step = $speed
			If $posWidth > $posWidthDest Then $step = -$step
			If Not $posWidthDest And $posWidth + $step < 0 Then
				$step = -$posWidth
			ElseIf $posWidthDest And $posWidth + $step > $posWidthDest Then
				$step = $posWidthDest - $posWidth
			EndIf
			$posWidth += $step
			$posLeft += -$step
			WinMove($hToast, "", $posLeft, $posTop, $posWidth, $posHeight)
			If $posWidth = $posWidthDest Then
				If Not $posWidth Then
					GUISetState(@SW_HIDE)
					$popupTime = Null
				EndIf
			EndIf
		EndIf
		If $posWidthDest Then
			For $i = 0 To 255
				If (_IsPressed(Hex($i), $hUser32_Dll)) Then
					closePopup()
				EndIf
			Next
		EndIf
	EndIf
;~ $hwnd = WinGetHandle($class)

;~ If $hwnd And $hwnd <> $prevHwnd Then
;~ 	$prevHwnd = $hwnd
;~ 	processPopup($hwnd)
;~ EndIf

	Sleep(10)
WEnd

Func _exit()
	DllClose($hUser32_Dll)
	If $hWinHook Then _WinAPI_UnhookWinEvent($hWinHook)
	If $hHookFunc Then DllCallbackFree($hHookFunc)
	FileDelete($imagePath)
	debug("exit")
EndFunc   ;==>_exit

Func _WinEventProc($hHook, $iEvent, $hwnd, $iObjectID, $iChildID, $iEventThread, $imsEventTime)
	If WinGetTitle($hwnd) = "VCarve Pro" Then
		processPopup($hwnd)
	EndIf

EndFunc   ;==>_WinEventProc

Func closePopup()
	debug("closepopup")
	$posWidthDest = 0
EndFunc   ;==>closePopup

Func iniSave()
	IniWrite($ini, $iniSection, "move", $settingMove ? 1 : 0)
	IniWrite($ini, $iniSection, "type", $settingType)
	IniWrite($ini, $iniSection, "autoStart", $settingAutoStart ? 1 : 0)
EndFunc   ;==>iniSave

Func movePopup($hPopup, $winPos = WinGetPos($hPopup), $button1Pos = ControlGetPos($hPopup, "", $button1))
	; Calculate the new window position based on the button position and current cursor position
	Local $newX = MouseGetPos(0) - $button1Pos[0] - $button1Pos[2] / 2
	Local $newY = MouseGetPos(1) - $button1Pos[1] - $button1Pos[3] * 1.5

	; Check if the new position is outside of the current monitor
	Local $monitorCount = _WinAPI_GetSystemMetrics(80)
	Local $monitors = _WinAPI_EnumDisplayMonitors()
	Local $rectX = 0, $rectY = 0, $rectW = 0, $rectH = 0
	For $i = 1 To $monitors[0][0]
		Local $monitorInfo = _WinAPI_GetMonitorInfo($monitors[$i][0])
		Local $monitorX = DllStructGetData($monitorInfo[1], 1)
		Local $monitorY = DllStructGetData($monitorInfo[1], 2)
		Local $monitorW = DllStructGetData($monitorInfo[1], 3)
		Local $monitorH = DllStructGetData($monitorInfo[1], 4)
		If $monitorX < $rectX Then $rectX = $monitorX
		If $monitorY < $rectY Then $rectY = $monitorY
		If $monitorW > $rectW Then $rectW = $monitorW
		If $monitorH > $rectH Then $rectH = $monitorH
	Next
	If $newX + $winPos[2] > $rectW Then $newX = $rectW - $winPos[2]
	If $newY + $winPos[3] > $rectH Then $newY = $rectH - $winPos[3]
	If $newX < $rectX Then $newX = $rectX
	If $newY < $rectY Then $newY = $rectY
	; Move the message box window to the new position
	WinMove($hPopup, "", $newX, $newY, $winPos[2], $winPos[3])
;~ WinActivate($hPopup)
EndFunc   ;==>movePopup

Func processPopup($hPopup = Null)
	debug("popup detected", $hPopup)
	If Not $hPopup And Not $sText Then Return
	Local $start = TimerInit()
	Local $winPos, $hBUtton1, $button1Pos, $isConfirm
	If $hPopup Then
		$winPos = WinGetPos($hPopup)
		$hBUtton1 = ControlGetHandle($hPopup, "", $button1)
		$button1Pos = ControlGetPos($hPopup, "", $hBUtton1)
		$isConfirm = ControlGetHandle($hPopup, "", $button2)
	EndIf
	If $isConfirm Or Not $settingType Then
		$sText = ""
		If $settingMove Then movePopup($hPopup, $winPos, $button1Pos)
	Else
		If $hPopup Then
			WinMove($hPopup, "", $posOut, $posOut)
			Local $imgPos = $winPos
			If Not $imgPos[3] Then
				For $i = 0 To 100
					$imgPos = WinGetPos($hPopup)
					If $imgPos[3] Then
						ExitLoop
					EndIf
					Sleep(10)
				Next
			EndIf
			If Not $button1Pos[1] Then
				For $i = 0 To 100
					$button1Pos = ControlGetPos($hPopup, "", $hBUtton1)
					If $button1Pos[1] Then

						ExitLoop
					EndIf
					Sleep(10)
				Next
			EndIf
			$imgPos[3] -= $imgPos[3] - $button1Pos[1]
			Local $iBorder = _WinAPI_GetSystemMetrics($SM_CXSIZEFRAME) / 2 - 0
			; Extract the coordinates of the primary monitor's display area
			Local $tRect = _WinAPI_GetWorkArea()
			; Get the bottom right corner
			$iRight = DllStructGetData($tRect, "Right")
			Local $iBottom = DllStructGetData($tRect, "Bottom")
			$posWidthDest = $imgPos[2] - $iBorder * 4
			$posWidthDestPrev = $posWidthDest
			$speed = $posWidthDest / $animationSpeed
			$posWidth = 0
			$posLeft = $iRight
			$posTop = $iBottom - $imgPos[3] - $iBorder * 2
			$posHeight = $imgPos[3] + $iBorder * 2
		Else
			$posWidthDest = $posWidthDestPrev
			$posWidth = 0
			$posLeft = $iRight
;~ If $speed < 0 Then $speed = -$speed
		EndIf
		debug($posLeft, $posWidth)
		WinMove($hToast, "", $posLeft, $posTop, $posWidth, $posHeight)
		If $hPopup Then
			GUICtrlSetPos($idPic, 0, 0, 0, 0)
			GUICtrlSetPos($idPic, 0, 0, $posWidthDest, $posHeight)
			Local $hDC = _WinAPI_GetDC($hPic)
			Local $hDestDC = _WinAPI_CreateCompatibleDC($hDC)
			Local $hBitmap = _WinAPI_CreateCompatibleBitmap($hDC, $posWidthDest, $posHeight)
			Local $hDestSv = _WinAPI_SelectObject($hDestDC, $hBitmap)
			Local $hSrcDC = _WinAPI_CreateCompatibleDC($hDC)
			Local $hBmp = _WinAPI_CreateCompatibleBitmap($hDC, $posWidthDest, $posHeight < 40 ? 40 : $posHeight)
			Local $hSrcSv = _WinAPI_SelectObject($hSrcDC, $hBmp)
			ControlHide($hToast, "", $hBUtton1) ;give little extra free space
			_WinAPI_PrintWindow($hPopup, $hSrcDC, True)
			ControlShow($hToast, "", $hBUtton1)
			debug("print", TimerDiff($start))
			_ScreenCapture_SaveImage($imagePath, $hBmp, True)
			$sText = StringStripWS(_UWPOCR_GetText($imagePath, Default, True), 3)
;~ Local $TITLE = WinGetTitle($hPopup)
		EndIf
		debug($sText)
		debug("text", TimerDiff($start))
		If Not $sText Or StringRegExp($sText, "(?i)error|exceed") Then
			$sText = ""
			If $hPopup Then
				If $settingMove Then
					movePopup($hPopup, $winPos, $button1Pos)
				Else
					WinMove($hPopup, "", $winPos[0], $winPos[1])
				EndIf
			EndIf
		Else
			If $hPopup Then
				_WinAPI_BitBlt($hDestDC, 0, 0, $posWidthDest, $posHeight, $hSrcDC, 0, 0, $MERGECOPY)
				; Set bitmap to control
				_SendMessage($hPic, $STM_SETIMAGE, 0, $hBitmap)
				Local $hObj = _SendMessage($hPic, $STM_GETIMAGE)
				If $hObj <> $hBitmap Then
					_WinAPI_DeleteObject($hBitmap)
				EndIf
			EndIf
			If $settingType = 1 Then GUISetState(@SW_SHOWNOACTIVATE)
			debug("show", TimerDiff($start))
			If $settingType = 2 Then
				TrayTip("", "", 0, 16)
				TrayTip("", $sText, 1, 16)
			EndIf
			If $hPopup Then
				ControlSend($hPopup, "", $hBUtton1, "{ESC}")
;~ ControlClick($hPopup, "", $hButton1) ;shows window context menu for some reason
;~ WinClose($hPopup) ;slow, 200ms
			EndIf
			debug("close", TimerDiff($start))
			$popupTime = TimerInit()
		EndIf
		If $hPopup Then
			_WinAPI_ReleaseDC($hPic, $hDC)
			_WinAPI_SelectObject($hDestDC, $hDestSv)
			_WinAPI_SelectObject($hSrcDC, $hSrcSv)
			_WinAPI_DeleteDC($hDestDC)
			_WinAPI_DeleteDC($hSrcDC)
			_WinAPI_DeleteObject($hBmp)
		EndIf
	EndIf
	setTray()
EndFunc   ;==>processPopup

Func setTray($line = @ScriptLineNumber)
	debug("setTray", $line)
	TrayItemSetState($trayMove, $settingMove ? $TRAY_CHECKED : $TRAY_UNCHECKED)
	TrayItemSetState($trayAutoStart, $settingAutoStart ? $TRAY_CHECKED : $TRAY_UNCHECKED)
	TrayItemSetState($trayType0, $settingType = 0 ? $TRAY_CHECKED : $TRAY_UNCHECKED)
	TrayItemSetState($trayType1, $settingType = 1 ? $TRAY_CHECKED : $TRAY_UNCHECKED)
	TrayItemSetState($trayType2, $settingType = 2 ? $TRAY_CHECKED : $TRAY_UNCHECKED)
	TrayItemSetState($trayType3, $settingType = 3 ? $TRAY_CHECKED : $TRAY_UNCHECKED)
	TrayItemSetState($trayLast, $sText ? $TRAY_ENABLE : $TRAY_DISABLE)
	If @Compiled Then
		If $settingAutoStart Then
			FileCreateShortcut(@ScriptFullPath, @StartupDir & "\VCarve'er.lnk")
		Else
			FileDelete(@StartupDir & "\VCarve'er.lnk")
		EndIf
	Else
		TrayItemSetState($trayAutoStart, $TRAY_DISABLE)
	EndIf
EndFunc   ;==>setTray

Func TrayEvent()
	Switch @TRAY_ID
		Case $trayMove
			$settingMove = Not BitAND(TrayItemGetState(@TRAY_ID), $TRAY_CHECKED)
		Case $trayAutoStart
			$settingAutoStart = Not BitAND(TrayItemGetState(@TRAY_ID), $TRAY_CHECKED)
		Case $trayType0
			$settingType = 0
		Case $trayType1
			$settingType = 1
		Case $trayType2
			$settingType = 2
		Case $trayType3
			$settingType = 3
		Case $trayExit
			Exit
		Case $trayLast
			processPopup()
			Return
	EndSwitch

	setTray()
	iniSave()
EndFunc   ;==>TrayEvent
