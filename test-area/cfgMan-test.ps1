param(
    [string[]] $setVars,
    [string] $path,
    [switch] $parse
)
$cfgRollPath = './cfgRoll.ps1'


Class File {
    [string]  $Path
    [boolean] $Missing = $true
    [boolean] $GotAllContent = $false
    [boolean] $GotContent = $false
    [System.IO.FileSystemInfo]$FSI
    $Content
    [string]$Time
    
    File ([string] $path) {
        $this.path = $path
        if (!(Test-Path $path)) { return }
        $this.FSI = gi $path
        $this.Missing = !($this.FSI.Exists -and $this.FSI.Directory)
        $this.Time = $this.FSI.LastWriteTimeUtc.ToString([cfgInfo]::timeFormat)
    }
    File ([System.IO.FileSystemInfo] $FSI) {
        $this.FSI = $FSI
        $this.FSI.FullName = $this.Path
        if ($this.FSI.Exists) {
            $this.Missing = !($this.FSI.Exists -and $this.FSI.Directory)
            $this.Time = $this.FSI.LastWriteTimeUtc.ToString([cfgInfo]::timeFormat)
        }
    }
    
    [string] GetContent() {
        if (!$this.GotContent) { $this.RefreshContent() }
        return $this.Content    
    }
    [string] RefreshContent([int]$lines = 0) {
        if ($lines -lt 0) {
            $this.GotAllContent = $false
            $this.Content = gc $this.FSI -Raw -Last (-$lines)
            if ($this.Content.length) {
                $this.GotContent = $true
            }
            else {
                $this.GotContent = $false
            }
            return $this.Content
        } if ($lines -gt 0) {
            $this.GotAllContent = $false
            $this.Content = gc $this.FSI -Raw -First $lines	
            if ($this.Content.length) {
                $this.GotContent = $true
            }
            else {
                $this.GotContent = $false
            }
            return $this.Content
        }
        $this.Content = gc $this.FSI -Raw
        if ($this.Content.length) {
            $this.GotContent = $true
            $this.GotAllContent = $true
        }
        else {
            $this.GotContent = $false 
            $this.GotAllContent = $false
        }
        return $this.Content
    }
    DropContent() {
        $this.Content = [string]::new('')
        $this.GotContent = $this.GotAllContent = $false
    }
}
Class cfgInfo {
    static [string] $callPattern = '\. \.[/\\]cfgMan\.ps1 -get'
    static [string] $timeFormat = 'MMssyyHHddmm'
    static [File] $Roll = [File]::new($Script:cfgRollPath)
    static [boolean] $rollMissing = [cfgInfo]::Roll.Missing
    static [hashtable] $oldRoll
    static [hashtable] $newRoll
    
    # scriptTime=''
    # rollTime=''
    # boxTime=''
    [File] $Script
    [File] $Box
    [string[]] $varList
    [string[]] $LastKnownTimes
    
    [boolean] $ListMissing = $true
    [boolean] $Skip = $false
    [boolean] $IsNew = $false
    [boolean] $UpdateList = $false
    [boolean] $UpdateValues = $false
    [boolean] $Ready = $false
    
    cfgInfo ([string] $path) {
        $this.Script = [File]::new($path)
        
        # Do the needful to be ready to set variables for this script
        #  OR be ready to write to files to get the cfgBox up to date
        #  with varList and value changes if any.
        $this.Prepare()
    }
    cfgInfo ([string] $path, [string[]]$varList) {
        $this.Script = [File]::new($path)
        # If provided, Always default to the provided varList
        # Simply [boolean]$this.varList to check if varList is available
        $this.varList = $varList
        $this.Prepare()
    }
    Prepare() {
        if ($this.Script.Missing) {
            # no script at path => Skip
            $this.Skip = $true
            return
        }
        $this.Box = [File]::new($this.findBoxPath())
        if ($this.Skip) { return }
        if ($this.Box.Missing) {
            # if box doesn't exist, find out why:
            if (!$this.GetList() -or !$this.makeNewBox()) {
                # if there's no requested varList in the script OR
                # I don't have write perms to cfgbox dir => Skip this script
                $this.Skip = $true
                return 
            }
            $this.UpdateList()
        }
        
    }
    [string] findBoxPath() {
        $rel = $this.Script.FSI.Directory | Resolve-Path -Relative
        if ($rel -match '\.\.') {
            $this.Skip = $true
            return ''
        }
        return './cfgBox/' + $rel + '/' + $this.Script.FSI.BaseName + '.cfgBox' + $this.Script.FSI.Extension
    }
    [boolean] makeNewBox() {
        ni $this.Box.Path -Force
        if (Test-Path $this.Box.Path) {
            $this.Box = [File]::new($this.Box.Path)
            return $true
        }
        return $false
    }
    [string[]] GetList() {
        # check if varList available
        if ($this.varList) { return $this.varList }
        
        # find cfgManCall in the script
        if ($slice = $this.Script.GetContent() | sls '^(.*\n)*.*'+[cfgInfo]::callPattern+'[^\n]*\n') {
            iex($slice.Matches.Groups[0].Value -replace [cfgInfo]::callPattern, '$this.varList=') 2>&1>$null
            $this.Script.DropContent()
        }
        return $this.varList
    }
    [hashtable] GetRoll() {
        if ([cfgInfo]::rollMissing) {
            throw 'cfgRoll file not found at:' + [cfgInfo]::Roll.Path
        }
        # if available, return it
        if ([cfgInfo]::oldRoll.Count -gt 0) { return [cfgInfo]::oldRoll }
        # if not available, get roll
        [cfgInfo]::newRoll = [cfgInfo]::oldRoll = &[cfgInfo]::Roll.Path
        return [cfgInfo]::oldRoll
    }
    UpdateList() {
        [string[]] $List = $this.GetList()
        [hashtable]$cfgRoll = $this.GetRoll()
        
        # [1] find new vars to add to cfgRoll
        
        # using cmdlets, easy, pipelined but does extra work, thus slow
        # $diff = diff $List $cfgRoll.Keys -CaseSensitive
        # $diff = $diff | ? -Property SideIndicator -eq '<=' 
        # $diff = $diff | select -ExpandProperty InputObject
        
        # simple O(nlogn) lookup, still faster than diff cmdlet method above
        [string[]] $diff = @()
        foreach ($v in $List) {
            if (!$cfgRoll.contains($v)) {
                $diff += $v
            }
        }
        # check if any new vars found
        if ($diff.count -ne 0) {
            # mark for Value update
            $this.UpdateValues = $true
            # add new vars to cfgRoll
            foreach ($v in $diff) { [cfgInfo]::newRoll.Add($v, '') }
            
            
            
        }
        $this.bumpScript()
        
    }
    # hasCfgmanCall() {}
    # getListFromScript() {}
    # getListFromBox(){}
    # makeBox() {}
    # [boolean] checkList() { return $false }
    # [boolean] checkValues() { return $false }
    # [boolean] needsListUpdate() { return $false }
    # [boolean] needsValuesUpdate() { return $false }
    # saveBox(){}
    # [System.IO.FileSystemInfo] getScript() { return $this.scriptPath }
    # [System.IO.FileSystemInfo] getBox() { return gi $this.getBoxPath() }
}







function Make-Roll {
    # init cfgRoll from cfgRef
}
function Sync-Roll {
    #returns false for no probs, else exit msg
    if (!(Test-Path ./cfgRoll.ps1)) {
        return Make-Roll
    }
    $rollFile = gi ./cfgRoll.ps1
    try {
        $lastUpdate = gc ./cfgBox/cfgRollLastUpdated.txt
    }
    catch {}
    if ($rollFile.LastWriteTimeUtc.ToString() -ne $lastUpdate) {
        return Update-Roll
    }
    return $false
}
function Get-Vars([string[]] $varList) {
    
}

function Set-Vars([string[]] $toSetVarList) {}
function Update-Roll() {
    $newroll = get-roll + Find-newvars
    Check-nonnull $newroll
}
function Get-Roll() {
    return $roll = ./cfgRoll.ps1
}

# function Get-VNamesFromScript([string] $script) {
# $content = gi $script | gc -raw | sls '^(.*\n)*.*\. \.[/\\]cfgMan\.ps1[^\n]*\n'
# iex($content.Matches.Groups[0].Value -replace '\. \.[/\\]cfgMan\.ps1 -get', '$varList=') 2>&1>$null
# return $varList
# }
function Find-NewVars() {
    return [string[]] $ListOfnewVarNames
}
function Check-NonNull([string[]]$ListtoValidate) {
    return [bool]$yesORno 
}  
function Filter-Null([string[]]$ListtoFilter) {
    return [string[]]$nonnull
}
function Check-cfgBox {
    [cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [string]$path
    )
    process {
        $box = cfgBox($path)
        $box = if (Test-path ($box)) {
            gi $box
        }
        else {	return 'New' }
    
        $times = (gc -First 4) -split "`t"
        $script = gi $path
        $syncStr = ''
        if ($times[1] -ne $script.LastWriteTime.toString('MMM-dd-yyyy HH:mm:ss')) {
            $syncStr += 'List'
        }
        $roll = gi ./cfgbox/cfgRoll.ps1
        $rollTime = $roll.LastWriteTime
        if ($times[3] -ne $rollTime.ToString('MMM-dd-yyyy HH:mm:ss') -or
            $times[5] -ne $box.LastWriteTime.ToString('MMM-dd-yyyy HH:mm:ss')) {
            $syncStr += 'Value'
        }
        return $syncStr
    }
    <#
    $script = gi $path
    $box = gi ./cfgBox/script.cfgBox.ps1
    $times = (gc $box -First 4) -split "`t"
    if ($times[1] -ne $script.LastWriteTime.toString('MMM-dd-yyyy HH:mm:ss')) { return $false }
    $roll = gi ./cfgbox/cfgRoll.ps1
    $rollTime = $roll.LastWriteTime
    if ($times[3] -ne $rollTime.ToString('MMM-dd-yyyy HH:mm:ss')) { return $false }
    if ($rollTime -gt $box.LastWriteTime.AddSeconds(5)) { return $false }
    if ($times[5] -ne $box.LastWriteTime.ToString('MMM-dd-yyyy HH:mm:ss')) { return $false }
    return $true
    #>
}
# function cfgBox([string]$path) {
#     $gi = gi $path
#     $rel = $gi.Directory | Resolve-Path -Relative
#     if ($rel -match '\.\.') { return $false }
#     return './cfgBox/' + $rel + '/' + $gi.BaseName + '.cfgBox' + $gi.Extension
# }
function Try-Sync {
    param(
        [string]$syncStr
    )
    process {
        if ($syncStr -match 'New') {
            $
        }
    }
}
function Update-cfgBox([string]$script) {
    $script = gi $script
    $scriptRel = $script | Resolve-Path -Relative
    $roll = gi ./cfgBox/cfgRoll.ps1
    $box = gi ./cfgBox/script.cfgBox.ps1
    gc $script -raw | ac $roll
    gc $roll -raw | ac $box
    $roll.Refresh()
    $box.Refresh()
    $boxHead = "<#`n"
    $boxhead += $script.LastWriteTime.toString('MMM-dd-yyyy HH:mm:ss') + "`tLast updated time( " + $scriptRel + " )`n"
    $boxHead += $roll.LastWriteTime.toString('MMM-dd-yyyy HH:mm:ss') + "`tLast updated time( cfgRoll )`n"
    $boxHead += (Get-Date).toString('MMM-dd-yyyy HH:mm:ss') + "`tLast updated time( cfgBox )`n"
    $boxhead += "#>`n"
    $boxhead  | sc $box
}

$toSetVarList = (($setVars -replace '[^\s\w\d_]'
    ).trim() | ? {
        $_.length -gt 0
    }) -replace ' ', '_'

# if ($toSetVarList) {
# 	Get-Vars $toSetVarList
# }
# elseif (!($out = Sync-Roll)) {
# 	"`n No updates to cfgRoll were detected.`n"
# }
# else {
# $out
# }
if ($parse) {
    Get-VNamesFromScript $path
}
else {
    Check-cfgBox $path
}


