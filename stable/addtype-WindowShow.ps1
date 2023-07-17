# Adds functions under the class WindowShow from winuser.h
# for setting the foreground window and its state
#
#     SetForegroundWindow (IntPtr WindowHandle)
#         Gives focus to this window
#         (doesn't change show state, so no restore if minimized)
#
#     ShowWindow (IntPtr WindowHandle, int setShowState)
#         Sets window's Show state
#             setStatusCodes:     0       3         6           9
#             Window Status:      Hide    Maximize  Minimize    Restore
#         for more, See
# https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-showwindow#parameters
#
#     IsIconic (IntPtr WindowHandle)
#         Checks if Window is minimized
#
#     IsZoomed (IntPtr WindowHandle)
#         Checks if maximized
#
#     IsWindow (IntPtr WindowHandle)
#         Check if window exists
#
#     OpenIcon (IntPtr WindowHandle)
#         Restore and activate a minimized window
#
# Get window handles with
#     (Get-Process)[0].MainWindowHandle
#

Add-Type -PassThru -Namespace Grim -Name HandleWindow -MemberDefinition @'
    [DllImport("user32.dll", SetLastError=true)]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool IsWindow(IntPtr hWnd);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool IsZoomed(IntPtr hWnd);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool OpenIcon(IntPtr hWnd);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool MoveWindow(IntPtr hWnd, int nX, int nY, int nWidth, int nHeight, bool bRepaint);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool AnimateWindow(IntPtr hWnd, IntPtr dwTime, IntPtr dwFlags);
'@