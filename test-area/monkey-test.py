# (measure-command{C:\SDK\Android\tools\bin\monkeyrunner.bat "'$pwd\test-area\monkey-test.py'"}).TotalMilliseconds
from com.android.monkeyrunner import MonkeyRunner, MonkeyDevice
device = MonkeyRunner.waitForConnection()

# TODO can't multitouch


# menu btn
device.touch(1855,65,device.DOWN)
MonkeyRunner.sleep(0.1)
device.touch(1855,65,device.UP)

MonkeyRunner.sleep(0.7)
# down btn
device.touch(1000,450,device.DOWN)
MonkeyRunner.sleep(0.1)
device.touch(1000,450,device.UP)


MonkeyRunner.sleep(4)
# Left hold
device.touch(250,450,device.DOWN)
# # Pan right hold
# device.touch(450,450,device.DOWN)

# MonkeyRunner.sleep(0.8)
# # Pan Left hold (Pan Right release)
# device.touch(450,450,device.UP)

# MonkeyRunner.sleep(0.8)
# # Pan right hold
# device.touch(450,450,device.DOWN)

# MonkeyRunner.sleep(0.8)
# # Pan Left hold (Pan Right release)
# device.touch(450,450,device.UP)


MonkeyRunner.sleep(1.5)
# down btn
device.touch(1000,450,device.DOWN)
MonkeyRunner.sleep(0.1)
device.touch(1000,450,device.UP)

MonkeyRunner.sleep(3)
# down btn
device.touch(1000,450,device.DOWN)
MonkeyRunner.sleep(0.1)
device.touch(1000,450,device.UP)





# Pan Right release
device.touch(450,450,device.UP)
# Pan Left release
device.touch(300,450,device.UP)

