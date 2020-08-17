{.experimental: "codeReordering".}

import os
import tables
import random
import strformat
import wkeynames
import winim
import wNim/[
    wApp, wIcon, wFrame, wPanel, wFont,
    wStaticBox, wStaticText,
    wButton, wSpinCtrl, wComboBox]


# -------------------------------------------------------------------
# Auto clicker stuff
# -------------------------------------------------------------------
var autoclick = false

type
  MouseKeyType {.pure.} = enum None, Left, Right, Middle
  AutoKeyType {.pure.} = enum None, Trigger, ToClick
  AutoKeyData = object
    mouse: MouseKeyType
    keyboard: DWORD

var curKeyboardAutoKeyType = AutoKeyType.None
var triggerKey = AutoKeyData(mouse: MouseKeyType.None, keyboard: 0)
var toClickKey = AutoKeyData(mouse: MouseKeyType.None, keyboard: 0)

var clickDelay = 20 .. 20
var clickHoldTime = 30 .. 30

proc hasToClickKey(): bool =
  toClickKey.mouse != MouseKeyType.None or
  toClickKey.keyboard != 0
proc hasKeyConflictMouse(): bool = 
  triggerKey.mouse != MouseKeyType.None and
  toClickKey.mouse != MouseKeyType.None and
  triggerKey.mouse == toClickKey.mouse
proc hasKeyConflictKeyboard(): bool = 
  triggerKey.keyboard != 0 and
  toClickKey.keyboard != 0 and
  triggerKey.keyboard == toClickKey.keyboard


# -------------------------------------------------------------------
# Channels
# -------------------------------------------------------------------
var chan_Status: Channel[bool]


# -------------------------------------------------------------------
# GUI Element
# -------------------------------------------------------------------
let frame = Frame(title="Nim Auto Clicker", style=wDefaultFrameStyle or wModalFrame)
frame.icon = Icon("", 0) # load icon from exe file.
frame.disableMaximizeButton()
frame.dpiAutoScale:
  frame.size = (400, 600)
  frame.minSize = (400, 600)
  frame.maxSize = (400, 600)

let panel = Panel(frame)

let box_Info = StaticBox(panel, label="Info")
let txt_Info = StaticText(panel, label="Press ESC to stop.\nPress WINDOWS key to reset trigger key.")

let box_Status = StaticBox(panel, label="Status")
let txt_AutoClickStatus = StaticText(panel, label="Auto Click: OFF")
txt_AutoClickStatus.font = Font(10, weight = wFontWeightBold)

let box_ClickDelay = StaticBox(panel, label="Click delay (ms)")
let box_ClickHoldTime = StaticBox(panel, label="Click hold time (ms)")

let spc_ClickDelay_Min = SpinCtrl(panel, value=clickDelay.a, style=wSpArrowKeys)
let spc_ClickDelay_Max = SpinCtrl(panel, value=clickDelay.b, style=wSpArrowKeys)
let spc_ClickHoldTime_Min = SpinCtrl(panel, value=clickHoldTime.a, style=wSpArrowKeys)
let spc_ClickHoldTime_Max = SpinCtrl(panel, value=clickHoldTime.b, style=wSpArrowKeys)

let box_Trigger = StaticBox(panel, label="Trigger Key (Toggle)")
let box_ToClick = StaticBox(panel, label="Click Key")

const mouseKeyChoices = ["None", "Mouse: Left Click", "Mouse: Right Click", "Mouse: Middle Click"]
let cbb_Trigger = ComboBox(panel, value="None", choices=mouseKeyChoices, style=wCbReadOnly)
let cbb_ToClick = ComboBox(panel, value="None", choices=mouseKeyChoices, style=wCbReadOnly)

let btn_Trigger = Button(panel, label="Set keyboard key")
let btn_ToClick = Button(panel, label="Set keyboard key")


# -------------------------------------------------------------------
# Layout
# -------------------------------------------------------------------
proc layout() =
  panel.autolayout """
    H:|-[box_Info, box_Status, box_ClickDelay, box_ClickHoldTime, box_Trigger, box_ToClick]-|
    V:|-[box_Info(86)]
       -[box_Status(66)]
       -[box_ClickDelay(50)]
       -[box_ClickHoldTime(50)]
       -[box_Trigger(120)]
       -[box_ToClick(120)]-|
    
    outer: box_Info
    H:|-[txt_Info]-|
    V:|-[txt_Info]-|
    
    outer: box_Status
    H:|-[txt_AutoClickStatus]-|
    V:|-[txt_AutoClickStatus]-|

    outer: box_ClickDelay
    H:|-[spc_ClickDelay_Min]-[spc_ClickDelay_Max(spc_ClickDelay_Min)]-|
    V:|[spc_ClickDelay_Min, spc_ClickDelay_Max]|

    outer: box_ClickHoldTime
    H:|-[spc_ClickHoldTime_Min]-[spc_ClickHoldTime_Max(spc_ClickHoldTime_Min)]-|
    V:|[spc_ClickHoldTime_Min, spc_ClickHoldTime_Max]|

    outer: box_Trigger
    H:|-[cbb_Trigger, btn_Trigger]-|
    V:|-[cbb_Trigger]-[btn_Trigger]-|
    
    outer: box_ToClick
    H:|-[cbb_ToClick, btn_ToClick]-|
    V:|-[cbb_ToClick]-[btn_ToClick]-|
  """


# -------------------------------------------------------------------
# Panel event
# -------------------------------------------------------------------
panel.wEvent_Size do (): layout()
panel.wEvent_LeftDown do (): panel.setFocus()


# -------------------------------------------------------------------
# Status
# -------------------------------------------------------------------
template updateStatus(body: untyped) =
  body
  txt_AutoClickStatus.label = "Auto Click: " & (if autoclick: "ON" else: "OFF")
  chan_Status.send(autoclick)


# -------------------------------------------------------------------
# Spin Ctrl helper
# -------------------------------------------------------------------
template updateSpcData(spcMin, spcMax: wSpinCtrl, minmax: Slice[int]) =
  spcMin.setValue(minmax.a)
  spcMax.setValue(minmax.b)
  spcMin.setRange(1 .. minmax.b)
  spcMax.setRange(minmax.a .. int32.high.int) # 텍스트 박스의 최댓값이 [int32]인가?

template clampMin(spcMin, spcMax: wSpinCtrl, minmax: var Slice[int], addAmount: int = 0) =
  updateStatus: autoclick = false
  minmax.b = max(spcMax.getValue(), minmax.a)
  minmax.a = min(max(spcMin.getValue() + addAmount, 1), minmax.b)
  updateSpcData(spcMin, spcMax, minmax)

template clampMax(spcMin, spcMax: wSpinCtrl, minmax: var Slice[int], addAmount: int = 0) =
  updateStatus: autoclick = false
  minmax.a = min(max(spcMin.getValue(), 1), minmax.b)
  minmax.b = max(spcMax.getValue() + addAmount, minmax.a)
  updateSpcData(spcMin, spcMax, minmax)


template spc_OnUpdateMin(spcMin, spcMax: wSpinCtrl, minmax: var Slice[int]) =
  spcMin.wEvent_TextEnter do (): clampMin(spcMin, spcMax, minmax)
  spcMin.wEvent_SpinUp do ():    clampMin(spcMin, spcMax, minmax, 1)
  spcMin.wEvent_SpinDown do ():  clampMin(spcMin, spcMax, minmax, -1)

template spc_OnUpdateMax(spcMin, spcMax: wSpinCtrl, minmax: var Slice[int]) =
  spcMax.wEvent_TextEnter do (): clampMax(spcMin, spcMax,minmax)
  spcMax.wEvent_SpinUp do ():    clampMax(spcMin, spcMax, minmax, 1)
  spcMax.wEvent_SpinDown do ():  clampMax(spcMin, spcMax, minmax, -1)


# -------------------------------------------------------------------
# Click Delay event
# -------------------------------------------------------------------
spc_OnUpdateMin(spc_ClickDelay_Min, spc_ClickDelay_Max, clickDelay)
spc_OnUpdateMax(spc_ClickDelay_Min, spc_ClickDelay_Max, clickDelay)


# -------------------------------------------------------------------
# Click Hold Time event
# -------------------------------------------------------------------
spc_OnUpdateMin(spc_ClickHoldTime_Min, spc_ClickHoldTime_Max, clickHoldTime)
spc_OnUpdateMax(spc_ClickHoldTime_Min, spc_ClickHoldTime_Max, clickHoldTime)


# -------------------------------------------------------------------
# Mouse combo box event
# -------------------------------------------------------------------
template selectMouseComboBox(cbb: wComboBox, mouseKey: var MouseKeyType) =
  updateStatus: autoclick = false
  mouseKey = case cbb.getValue()
  of mouseKeyChoices[1]: MouseKeyType.Left
  of mouseKeyChoices[2]: MouseKeyType.Right
  of mouseKeyChoices[3]: MouseKeyType.Middle
  else: MouseKeyType.None

template resetMouseComboBox(cbb: wComboBox, mouseKey: var MouseKeyType) =
  cbb.setValue("None")
  mouseKey = MouseKeyType.None

cbb_Trigger.wEvent_ComboBox do ():
  selectMouseComboBox(cbb_Trigger, triggerKey.mouse)
  resetKeyboardInputButton(btn_Trigger, triggerKey.keyboard)
  if hasKeyConflictMouse():
    resetMouseComboBox(cbb_ToClick, toClickKey.mouse)

cbb_ToClick.wEvent_ComboBox do ():
  selectMouseComboBox(cbb_ToClick, toClickKey.mouse)
  resetKeyboardInputButton(btn_ToClick, toClickKey.keyboard)
  if hasKeyConflictMouse():
    resetMouseComboBox(cbb_Trigger, triggerKey.mouse)


# -------------------------------------------------------------------
# Keyboard input button event
# -------------------------------------------------------------------
template clickKeyboardInputButton(btn: wButton, setKeyType: AutoKeyType) =
  updateStatus: autoclick = false
  btn.setFocus()
  if curKeyboardAutoKeyType == AutoKeyType.None:
    btn.label = "Press any key"
    curKeyboardAutoKeyType = setKeyType

template resetKeyboardInputButton(btn: wButton, key: var DWORD) =
  btn.label = "Set keyboard key"
  key = 0
  curKeyboardAutoKeyType = AutoKeyType.None

template finishKeyboradInputButton() =
  panel.setFocus()
  curKeyboardAutoKeyType = AutoKeyType.None

btn_Trigger.wEvent_LeftDown do ():
  clickKeyboardInputButton(btn_Trigger, AutoKeyType.Trigger)
  resetMouseComboBox(cbb_Trigger, triggerKey.mouse)
  if hasKeyConflictKeyboard():
    resetKeyboardInputButton(btn_ToClick, toClickKey.keyboard)

btn_ToClick.wEvent_LeftDown do ():
  clickKeyboardInputButton(btn_ToClick, AutoKeyType.ToClick)
  resetMouseComboBox(cbb_ToClick, toClickKey.mouse)
  if hasKeyConflictKeyboard():
    resetKeyboardInputButton(btn_Trigger, triggerKey.keyboard)


# -------------------------------------------------------------------
# Windows hook
# -------------------------------------------------------------------
var mouseHook: HHOOK
var keyboardHook: HHOOK

proc createHook() =
  mouseHook = SetWindowsHookExW(WH_MOUSE_LL, mouseCallback, 0, 0)
  keyboardHook = SetWindowsHookExW(WH_KEYBOARD_LL, keyboardCallback, 0, 0)

proc destroyHook() =
  UnhookWindowsHookEx(mouseHook)
  UnhookWindowsHookEx(keyboardHook)

proc mouseCallback(code: int32, wParam: WPARAM, lParam: LPARAM): LRESULT {.stdcall.} =
  defer: CallNextHookEx(mouseHook, code, wParam, lParam)
  let mouseStruct = cast[PMSLLHOOKSTRUCT](lParam)
  if mouseStruct != nil and mouseStruct.flags == 0:
    # Toggle autoclick
    if hasToClickKey() and triggerKey.mouse != MouseKeyType.None:
      let mouseCode = wParam.uint64
      let keyClicked = case triggerKey.mouse
      of MouseKeyType.Left: mouseCode == WM_LBUTTONDOWN
      of MouseKeyType.Right: mouseCode == WM_RBUTTONDOWN
      of MouseKeyType.Middle: mouseCode == WM_MBUTTONDOWN
      else: false
      if keyClicked:
        updateStatus: autoclick = not autoclick

proc keyboardCallback(code: int32, wParam: WPARAM, lParam: LPARAM): LRESULT {.stdcall.} =
  defer: CallNextHookEx(keyboardHook, code, wParam, lParam)
  let kbStruct = cast[PKBDLLHOOKSTRUCT](lParam)
  if kbStruct != nil and wParam == WM_KEYDOWN:
    let keyCode = kbStruct.vkCode
    # Set toggle key
    if curKeyboardAutoKeyType != AutoKeyType.None:
      let text = "Keyboard: " & keyCode.keyCodeToName()
      case curKeyboardAutoKeyType
      of AutoKeyType.Trigger:
        btn_Trigger.label = text
        triggerKey.keyboard = keyCode
      of AutoKeyType.ToClick:
        btn_ToClick.label = text
        toClickKey.keyboard = keyCode
      else: discard
      finishKeyboradInputButton()
    # Toggle autoclick
    elif hasToClickKey() and triggerKey.keyboard != 0 and keyCode == triggerKey.keyboard:
      updateStatus: autoclick = not autoclick
    # Stop autoclick
    if keyCode == wKey_Esc:
      updateStatus: autoclick = false
    # Stop and Reset toggle key
    if keyCode in {wKey_LWin, wKey_RWin}:
      updateStatus: autoclick = false
      resetMouseComboBox(cbb_Trigger, triggerKey.mouse)
      resetKeyboardInputButton(btn_Trigger, triggerKey.keyboard)


# -------------------------------------------------------------------
# Auto Click Thread
# -------------------------------------------------------------------
var autoClickThread: Thread[void]

const mouseEventKeys_Down = {
  MouseKeyType.Left:   MOUSEEVENTF_LEFTDOWN.DWORD,
  MouseKeyType.Right:  MOUSEEVENTF_RIGHTDOWN.DWORD,
  MouseKeyType.Middle: MOUSEEVENTF_MIDDLEDOWN.DWORD
}.toTable()
const mouseEventKeys_Up = {
  MouseKeyType.Left:   MOUSEEVENTF_LEFTUP.DWORD,
  MouseKeyType.Right:  MOUSEEVENTF_RIGHTUP.DWORD,
  MouseKeyType.Middle: MOUSEEVENTF_MIDDLEUP.DWORD
}.toTable()

proc autoClickThreadProc() {.thread.} =
  # variables
  var run {.global.} = true
  var delay {.global.} = clickDelay
  var holdTime {.global.} = clickHoldTime
  var mouseKey_Down {.global.}: DWORD
  var mouseKey_Up {.global.}: DWORD
  var keyboardKey {.global.}: BYTE
  
  # loop
  while true:
    sleep(1)
    let (dataAvailable, msg) = chan_Status.tryRecv()
    if dataAvailable:
      run = msg
      if run:
        delay = clickDelay
        holdTime = clickHoldTime
        if toClickKey.mouse != MouseKeyType.None:
          mouseKey_Down = mouseEventKeys_Down[toClickKey.mouse]
          mouseKey_Up = mouseEventKeys_Up[toClickKey.mouse]
        elif toClickKey.keyboard != 0:
          keyboardKey = toClickKey.keyboard.BYTE
    
    if not run:
      continue
    
    # Mouse
    if toClickKey.mouse != MouseKeyType.None:
      # down
      mouse_event(mouseKey_Down, 0, 0, 0, 0)
      sleep(rand(holdTime))
      # up
      mouse_event(mouseKey_Up, 0, 0, 0, 0)
      sleep(rand(delay))
    # Keyboard
    elif toClickKey.keyboard != 0:
      # down
      keybd_event(keyboardKey, 0, 0, 0)
      sleep(rand(holdTime))
      # up
      keybd_event(keyboardKey, 0, KEYEVENTF_KEYUP, 0)
      sleep(rand(delay))


# -------------------------------------------------------------------
# App
# -------------------------------------------------------------------
let app = App()

proc main() =
  randomize()

  # Setup channel
  chan_Status.open()
  defer: chan_Status.close()

  # Start autoclick thread
  autoClickThread.createThread(autoClickThreadProc)

  # Setup windows hook
  createHook()
  defer: destroyHook()
  
  # Setup GUI
  layout()
  panel.setFocus()
  frame.center()
  frame.show()
  app.mainLoop()

main()
