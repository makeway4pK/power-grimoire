#   Description: Script for launching a program/command only if certain
#   	conditions are met and optionally focusing(by simulating a mouseclick)
#  Author: makeway4pK
[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string] $Launch    #command to launch
    
    , [switch] $Online
    , [switch] $Gamepad
    , [switch] $Charging
    , [switch] $Admin
    
    , [switch] $NotOnline
    , [switch] $NotGamepad
    , [switch] $NotCharging
    , [switch] $NotAdmin
    
    # When a process named $Focus appears, click at $FocusAt
    # after $FocusDelay seconds
    # (1560,880) is bottom right
    , [string] $Focus
    , [int[]]  $FocusAt = @(780, 440)
    , [uint16] $FocusDelay = 10        
)
# online if connected to any of the following networks
. ./cfgMan.ps1 -get 'wifi_IDs'

if (!$Launch) { exit }
$ok = $true

if ($Admin -or $NotAdmin) {
    if ($Admin -and $NotAdmin) { exit }
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
                [Security.Principal.WindowsBuiltInRole] "Administrator")) {	$ok = $false }
    if ($NotAdmin) { $ok -= 1 }
    if (!$ok) { exit }
    # cancel if any condition not met
}

if ($Charging -or $NotCharging) {
    if ($Charging -and $NotCharging) { exit }
    if (!(Get-WmiObject -class BatteryStatus -Namespace root\wmi).PowerOnline) {
        $ok = $false
    }
    if ($NotCharging) { $ok -= 1 }
    if (!$ok) { exit }
    # cancel if any condition not met
}

if ($Online -or $NotOnline) {
    if ($Online -and $NotOnline) { exit }
    $ok = $false
    $networks = netsh wlan show interfaces
    foreach ($ID in $wifi_ids) {
        if ($networks -match [regex]::Escape($ID)) {
            $ok = $true
            break
        }
    }
    if ($NotOnline) { $ok -= 1 }
    if (!$ok) { exit }
    # cancel if any condition not met
}

# gamepad if 'game' or 'controller' found in any of Human Interface Devices' names
if ($Gamepad -or $NotGamepad) {
    if ($Gamepad -and $NotGamepad) { exit }
    $ok = $false
    $HIDs = Get-PnpDevice -PresentOnly -Class "HIDClass"
    foreach ($device in $HIDs) {                           
        if (($device.name -imatch [regex]::Escape("game")) -or ($device.name -imatch [regex]::Escape("controller"))) {
            $ok = $true
            break
        }
    }
    if ($NotGamepad) { $ok -= 1 }
    if (!$ok) { exit }
    # cancel if any condition not met
}



#launch if all chosen conditions met
if ($ok) {
	&$Launch $($MyInvocation.UnboundArguments -join ' ')
    if (!$?) { exit }
    
    if ($Focus) {
        While (!(Get-Process $Focus)) {
            # Increase wait time to accomodate for initialization (trial-error)
            Start-Sleep 1
        }
        Start-Sleep $FocusDelay
    
        $cSource = @'
using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public class Clicker
{
//https://msdn.microsoft.com/en-us/library/windows/desktop/ms646270(v=vs.85).aspx
[StructLayout(LayoutKind.Sequential)]
struct INPUT
{ 
    public int        type; // 0 = INPUT_MOUSE,
                            // 1 = INPUT_KEYBOARD
                            // 2 = INPUT_HARDWARE
    public MOUSEINPUT mi;
}

//https://msdn.microsoft.com/en-us/library/windows/desktop/ms646273(v=vs.85).aspx
[StructLayout(LayoutKind.Sequential)]
struct MOUSEINPUT
{
    public int    dx ;
    public int    dy ;
    public int    mouseData ;
    public int    dwFlags;
    public int    time;
    public IntPtr dwExtraInfo;
}

//This covers most use cases although complex mice may have additional buttons
//There are additional constants you can use for those cases, see the msdn page
const int MOUSEEVENTF_MOVED      = 0x0001 ;
const int MOUSEEVENTF_LEFTDOWN   = 0x0002 ;
const int MOUSEEVENTF_LEFTUP     = 0x0004 ;
const int MOUSEEVENTF_RIGHTDOWN  = 0x0008 ;
const int MOUSEEVENTF_RIGHTUP    = 0x0010 ;
const int MOUSEEVENTF_MIDDLEDOWN = 0x0020 ;
const int MOUSEEVENTF_MIDDLEUP   = 0x0040 ;
const int MOUSEEVENTF_WHEEL      = 0x0080 ;
const int MOUSEEVENTF_XDOWN      = 0x0100 ;
const int MOUSEEVENTF_XUP        = 0x0200 ;
const int MOUSEEVENTF_ABSOLUTE   = 0x8000 ;

const int screen_length = 0x10000 ;

//https://msdn.microsoft.com/en-us/library/windows/desktop/ms646310(v=vs.85).aspx
[System.Runtime.InteropServices.DllImport("user32.dll")]
extern static uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

public static void LeftClickAtPoint(int x, int y)
{
    //Move the mouse
    INPUT[] input = new INPUT[3];
    input[0].mi.dx = x*(65535/System.Windows.Forms.Screen.PrimaryScreen.Bounds.Width);
    input[0].mi.dy = y*(65535/System.Windows.Forms.Screen.PrimaryScreen.Bounds.Height);
    input[0].mi.dwFlags = MOUSEEVENTF_MOVED | MOUSEEVENTF_ABSOLUTE;
    //Left mouse button down
    input[1].mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
    //Left mouse button up
    input[2].mi.dwFlags = MOUSEEVENTF_LEFTUP;
    SendInput(3, input, Marshal.SizeOf(input[0]));
}
}
'@
        Add-Type -TypeDefinition $cSource -ReferencedAssemblies System.Windows.Forms, System.Drawing
        #Send a click at a specified point
        [Clicker]::LeftClickAtPoint([int]$Focus[1], [int]$Focus[2])
    }
}