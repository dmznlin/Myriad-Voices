rem 在启动目录中创建该脚本的快捷方式
rem C:\Users\Administrator\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup

set ws = CreateObject("WScript.Shell")
rem 等待Windows启动
WScript.Sleep 5000
ws.run """D:\Program Files\Netease\shell\MuMuPlayer.exe""" & " -p org.nobody.multitts -v 0",SW_SHOWNORMAL,False

rem 等待tts启动
WScript.Sleep 60000
ws.SendKeys "%(q)"
set ws = nothing