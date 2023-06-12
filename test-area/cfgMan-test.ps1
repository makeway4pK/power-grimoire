param(
    [string[]] $setVars,
    [string] $path,
    [switch] $parse
)
Class cfgInfo {
    static [File] $Roll = [File]::new('./cfgRoll.ps1')
    static [string] $callPattern = '\. \.[/\\]cfgMan\.ps1 -get'
    static [string] $timeFormat = 'MMssyyHHddmm'
    static [boolean] $rollMissing = [cfgInfo]::Roll.Missing
    static [hashtable] $oldRoll
    static [hashtable] $newRoll
    static [boolean] $GotRoll = $false
    
    # scriptTime=''
    # rollTime=''
    # boxTime=''
    [File] $Script
    [File] $Box
    [string[]] $varList
    [string] $LastKnownTimes
    
    [boolean] $GotList = $false
    [boolean] $CanSkip = $false
    [boolean] $IsNew = $false
    [boolean] $PendingList = $false
    [boolean] $PendingValues = $false
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
    [void] Prepare() {
        # no script at path => Skip
        if ($this.Script.Missing) { $this.CanSkip = $true; return }
        # find Box
        $this.Box = [File]::new($this.FindBoxPath())
        if ($this.CanSkip) { return }
        # if box missing, figure out why and make new box
        if ($this.Box.Missing) { $this.WhyNoBox() }
        if ($this.CanSkip) { return }
        # check for possible changes in varlist or values
        if (!$this.DetectDesync()) { $this.Ready = $true; return }
        # settle desync flags in order
        if ($this.PendingList) { $this.UpdateList() }
        if ($this.PendingValues) { $this.UpdateValues() }
        $this.Ready = !($this.PendingList -or $this.PendingValues)
    }
    [string] FindBoxPath() {
        $rel = $this.Script.FSI.Directory | Resolve-Path -Relative
        if ($rel -match '\.\.') {
            $this.CanSkip = $true
            return ''
        }
        return './cfgBox/' + $rel + '/' + $this.Script.FSI.BaseName + '.cfgBox' + $this.Script.FSI.Extension
    }
    [void] WhyNoBox() {
        # if box doesn't exist, find out why:
        if (!$this.GetList($true) -or !$this.MakeNewBox()) {
            # if there's no requested varList in the script OR
            # I don't have write perms to cfgbox dir => Skip this script
            $this.CanSkip = $true
            return 
        }
        # now that you got a list and made a new box,
        #  update List to get timestamps into it
        $this.UpdateList()
    }
    [boolean] MakeNewBox() {
        ni $this.Box.Path -Force
        if (Test-Path $this.Box.Path) {
            $this.Box = [File]::new($this.Box.Path)
            return $true
        }
        return $false
    }
    [string[]] GetList([boolean]$FromScript = $false) {
        # check if varList already retrieved
        if ($this.GotList) { return $this.varList }
        # getList from Box when possible
        if (!$FromScript) {
            $this.varList = &$this.Box.Path
            if ($this.varList) {
                $this.GotList = $true 
                return $this.varList 
            }
        }
        # find cfgManCall in the script
        if ($slice = $this.Script.GetContent() | sls '^(.*\n)*.*'+[cfgInfo]::callPattern+'[^\n]*\n') {
            # execute lines until the cfgMan call to get the varlist from script content
            iex($slice.Matches.Groups[0].Value -replace [cfgInfo]::callPattern, '$this.varList =') 2>&1>$null
            $this.Script.DropContent()
        }
        $this.GotList = $true
        return $this.varList
    }
    [hashtable] GetRoll() {
        # check if cfgRoll file was found
        if ([cfgInfo]::rollMissing) {
            throw 'cfgRoll file not found at:' + [cfgInfo]::Roll.Path
        }
        # if available, return it
        if ([cfgInfo]::GotRoll) { return [cfgInfo]::oldRoll }
        # if not available, get roll
        [cfgInfo]::newRoll = [cfgInfo]::oldRoll = &[cfgInfo]::Roll.Path
        [cfgInfo]::GotRoll = $true
        return [cfgInfo]::oldRoll
    }
    [void] UpdateList() {
        # get varList from script
        [string[]] $List = $this.GetList($true)
        [hashtable]$cfgRoll = $this.GetRoll()
        
        # [1] find new vars to add to cfgRoll
        # using cmdlets, easy but pipelined and does extra work, thus slow
        # $diff = diff $List $cfgRoll.Keys
        # $diff = $diff | ? -Property SideIndicator -eq '<=' 
        # $diff = $diff | select -ExpandProperty InputObject
        
        # simple O(nlogn) lookup, still faster than diff cmdlet method above
        [string[]] $diffs = @()
        foreach ($v in $List) { if (!$cfgRoll.contains($v)) { $diffs += $v } }
        # check if any new vars found
        if ($diffs.count -ne 0) {
            # mark for Value update
            $this.PendingValues = $true
            # add new vars to cfgRoll, no overwriting
            foreach ($v in $diffs) { [cfgInfo]::newRoll.Add($v, '') }
            # write to cfgRoll and cfgBox
            # TODO  stage changes to cfgRoll
            # TODO  stage changes to cfgBox
        }
        # note down Script's write time as ack of new vars found
        $this.bumpScript()
        # mark List updated
        $this.PendingList = $false
    }
    [void] UpdateValues() {
        # for this function always get varList from Box
        [string[]] $List = $this.GetList()
        [hashtable]$cfgRoll = $this.GetRoll()
        # find any undefined vars
        if ($this.FindUndefs()) { return }
        # if all vars are defined, merge values to box
        # TODO add values to cfgBox
        # note cfgRoll's last write time as ack values updated
        $this.bumpRoll()
        # mark Values update done
        $this.PendingValues = $false
    }
    [boolean] FindUndefs() {
        # get varList from box
        [string[]] $List = $this.GetList()
        [hashtable]$cfgRoll = $this.GetRoll()
        # Values are always strings or arrays of strings in cfgRoll
        #  So, casting to boolean is essentially a check to see if
        #  there are any non-empty strings in the value
        foreach ($v in $List) { if (!$cfgRoll[$v]) { return $true } }
        return $false
    }
    [boolean] DetectDesync() {
        $header = gc $this.Box.Path -Raw -First 1
        $len = [cfgInfo]::timeFormat.Length
        $off = 1
        $scriptStamp = $header.Substring($off, $len)
        $rollStamp = $header.Substring($off + $len, $len)
        $boxStamp = [datetime]::ParseExact($header.Substring($off + $len * 2, $len), [cfgInfo]::timeFormat)
        $flag = $false
        if ($scriptStamp -ne $this.Script.Time) { $this.PendingList = $true; $flag = $true }
        if ($boxStamp -lt [datetime]::ParseExact($this.Box.Time, [cfgInfo]::timeFormat) -or 
            $rollStamp -ne [cfgInfo]::Roll.Time) { $this.PendingValues = $true; $flag = $true }
        return $flag
    }
}
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
function Set-Vars([string[]] $toSetVarList) {}
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


