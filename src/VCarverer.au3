#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=../resources/vcarverer.ico
#AutoIt3Wrapper_Outfile=../bin/VCarverer_v1.0.0.exe
#AutoIt3Wrapper_UseX64=y
#AutoIt3Wrapper_Compression=4
#AutoIt3Wrapper_UseUpx=y
#AutoIt3Wrapper_Res_Description=VCarver'er - show messages popups as toast notifications
#AutoIt3Wrapper_Res_Fileversion=1.0.0.30
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=y
#AutoIt3Wrapper_Res_ProductVersion=1.0.0
#AutoIt3Wrapper_Res_LegalCopyright=©V@no 2024
#AutoIt3Wrapper_Res_Language=1033
#AutoIt3Wrapper_Res_Field=ProductName|VCarver'er
#AutoIt3Wrapper_Res_Field=BuildDate|%longdate%  %time%
#AutoIt3Wrapper_Run_Tidy=y
#AutoIt3Wrapper_Run_Au3Stripper=y
#Au3Stripper_Parameters=/pe /so /rm /rsln

#AutoIt3Wrapper_Run_Before=cd.>.stop
#AutoIt3Wrapper_Run_Before=cd.>../bin/.stop

#AutoIt3Wrapper_Run_After=rm ../bin/VCarverer.exe
#AutoIt3Wrapper_Run_After=mklink /h "../bin/VCarverer.exe" "%out%"
#AutoIt3Wrapper_Run_After=rm .stop
#AutoIt3Wrapper_Run_After=rm ../bin/.stop

#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****


#include <WinAPI.au3>
#include <_debug.au3>
#include <Misc.au3>
#include <ScreenCapture.au3>
#include <UWPOCR.au3>
#include <GuiConstants.au3>
Global Const $VERSION = "1.0.0.30"
Global Const $stopFile = @ScriptDir & "\.stop"
Global Const $timeout = 10000 ; notification message timeout in milliseconds
Global Const $animationSpeed = 4 ; animation speed 1 = fastest
Global Const $class = "[CLASS:#32770; TITLE:VCarve Pro]"
Global Const $button1 = "[CLASS:Button; INSTANCE:1]"
Global Const $button2 = "[CLASS:Button; INSTANCE:2]"
Global Const $posOut = -999999999999999999 ;move message box outside visible area
Global Const $hToast = GUICreate("", 0, 0, -1, -1, BitOR($WS_POPUP, 0), BitOR($WS_EX_LAYERED, $WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))
Global Const $idPic = GUICtrlCreatePic('', 0, 0, 0, 0)
Global Const $hPic = GUICtrlGetHandle($idPic)
Global Const $hUser32_Dll = DllOpen("user32.dll")
Global $popupTime
Global $posWidthDest
Global $posWidth
Global $posLeft
Global $posTop
Global $posHeight
Global $speed
Local $hwnd
Local $prevHwnd
Local $step

If _Singleton("VCarverer", 1) = 0 Then
	Exit
EndIf

Opt("WinTitleMatchMode", 3)
OnAutoItExitRegister("_exit")
TraySetToolTip("VCarver'er " & $VERSION)
FileCreateShortcut(@ScriptFullPath, @StartupDir & "\VCarverer.lnk")
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
	$hwnd = WinGetHandle($class)

	If $hwnd And $hwnd <> $prevHwnd Then
		$prevHwnd = $hwnd
		showPopup()
	EndIf

	Sleep(10)
WEnd

Func _exit()
	DllClose($hUser32_Dll)
	debug("exit")
EndFunc   ;==>_exit

Func closePopup()
	$posWidthDest = 0
EndFunc   ;==>closePopup

Func showPopup()
	debug("popup detected")
	Local $winPos = WinGetPos($hwnd)
	Local $button1Pos = ControlGetPos($hwnd, "", $button1)
;~ Local $isNew = BitAND($iStyle, $WS_POPUPWINDOW)
	Local $msg = ""
	If $winPos[2] = 250 And $winPos[3] = 109 Then
		$msg = "All toolpaths successfully recalculated"
	ElseIf $winPos[2] = 245 Then
		$msg = "Toolpath(s) recalculated successfully."
	ElseIf $winPos[2] = 424 Then
		$msg = "No toolpaths to recalculate"
;~ ElseIf $winPos[2] = 351 Then
;~ 	$msg = "No vectors selected ..."
;~ ElseIf $winPos[2] = 366 Then
;~ 	$msg = "One or more errors occured while recalculating toolpaths" & @CRLF & "Please check the data for the following toolpaths carefully"
	EndIf

	Local $isConfirm = ControlGetHandle($hwnd, "", $button2) Or Not $msg
	If $isConfirm Then
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
		WinMove($hwnd, "", $newX, $newY, $winPos[2], $winPos[3])
		WinActivate($hwnd)
	Else
		WinMove($hwnd, "", $posOut, $posOut)
		Local $iSize = $winPos
		If Not $iSize[3] Then
			For $i = 0 To 100
				$iSize = WinGetPos($hwnd)
				If $iSize[3] Then
					ExitLoop
				EndIf
				Sleep(10)
			Next
		EndIf
		If Not $button1Pos[1] Then
			For $i = 0 To 100
				$button1Pos = ControlGetPos($hwnd, "", $button1)
				If $button1Pos[1] Then

					ExitLoop
				EndIf
				Sleep(10)
			Next
		EndIf
;~ $button1Pos = ControlGetPos($hwnd, "", $button1)
		$iSize[3] -= $iSize[3] - $button1Pos[1]
		; Extract the coordinates of the primary monitor's display area
		Local $tRect = _WinAPI_GetWorkArea()
		; Get the bottom right corner
		Local $iRight = DllStructGetData($tRect, "Right")
		Local $iBottom = DllStructGetData($tRect, "Bottom")
		Local $iBorder = _WinAPI_GetSystemMetrics($SM_CXSIZEFRAME) / 2
		$posWidthDest = $iSize[2] - $iBorder * 2
		$speed = $posWidthDest / $animationSpeed
		$posWidth = 0
		$posLeft = $iRight
		$posTop = $iBottom - $iSize[3] + $iBorder
		$posHeight = $iSize[3] - $iBorder
		debug($posTop, $posHeight, $iSize)
		WinMove($hToast, "", $posLeft, $posTop, $posWidth, $posHeight)
		GUICtrlSetPos($idPic, 0, 0, 0, 0)
		GUICtrlSetPos($idPic, 0, 0, $posWidthDest, $posHeight)
		Local $hDC = _WinAPI_GetDC($hPic)
		Local $hDestDC = _WinAPI_CreateCompatibleDC($hDC)
		Local $hBitmap = _WinAPI_CreateCompatibleBitmap($hDC, $posWidthDest, $posHeight)
		Local $hDestSv = _WinAPI_SelectObject($hDestDC, $hBitmap)
		Local $hSrcDC = _WinAPI_CreateCompatibleDC($hDC)
		Local $hBmp = _WinAPI_CreateCompatibleBitmap($hDC, $posWidthDest, $posHeight)
		Local $hSrcSv = _WinAPI_SelectObject($hSrcDC, $hBmp)
		_WinAPI_PrintWindow($hwnd, $hSrcDC, True)
		WinClose($hwnd)
		_WinAPI_BitBlt($hDestDC, 0, 0, $posWidthDest, $posHeight, $hSrcDC, 0, 0, $MERGECOPY)

		_WinAPI_ReleaseDC($hPic, $hDC)
		_WinAPI_SelectObject($hDestDC, $hDestSv)
		_WinAPI_SelectObject($hSrcDC, $hSrcSv)
		_WinAPI_DeleteDC($hDestDC)
		_WinAPI_DeleteDC($hSrcDC)
		_WinAPI_DeleteObject($hBmp)

		; Set bitmap to control
		_SendMessage($hPic, $STM_SETIMAGE, 0, $hBitmap)
		Local $hObj = _SendMessage($hPic, $STM_GETIMAGE)
		If $hObj <> $hBitmap Then
			_WinAPI_DeleteObject($hBitmap)
		EndIf

		GUISetState(@SW_SHOWNOACTIVATE)
		$popupTime = TimerInit()
	EndIf
EndFunc   ;==>showPopup
