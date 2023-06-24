param(
	[string] $path,
	[string[]] $get,
	[switch] $parse
)
Class cfgInfo {
	static [string] $timeFormat = 'MMssyyHHddmm'
	static [File] $Roll = [File]::new('./cfgRoll.ps1')
	static [string] $callPattern = '\. \.[/\\]cfgMan\.ps1 -get'
	static [bool] $rollMissing = [cfgInfo]::Roll.Missing
	static [hashtable] $oldRoll
	static [hashtable] $newRoll
	static [bool] $GotRoll = $false
    
	[File] $Script
	[File] $Box
	[string[]] $varList
    
	[bool] $ScriptParsed = $false
	[bool] $GotList = $false
	[bool] $CanSkip = $false
	[bool] $PendingList = $false
	[bool] $PendingValues = $false
	[bool] $Ready = $false
    
	cfgInfo ([string] $path) {
		$this.Script = [File]::new($path)
        
		# Do the needful to be ready to set variables for this script
		#  OR be ready to write to files to get the cfgBox up to date
		#  with varList and value changes if any.
		$this.Prepare()
	}
	cfgInfo ([string[]]$varList) {
		$path = $Script:MyInvocation.ScriptName
		$this.Script = [File]::new($path)
		# If provided, Always default to the provided varList
		# Simply [bool]$this.varList to check if varList is available
		# After cleanup of course
		$this.varList = $this.CleanupList($varList)
		if ($this.varList) { $this.GotList = $true }    # this will let it skip parsing the script or box in case of new list
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
		if ($rel -match (resolve-path -relative cfgBox) -or
			$rel -match '\.\.'
		) {
			if ($rel -ne (resolve-path -relative.)) {
				$this.CanSkip = $true
				return ''
			}
			$rel = '.'
		}
		return './cfgBox/' + $rel + '/' + $this.Script.FSI.BaseName + '.cfgBox' + $this.Script.FSI.Extension
	}
	[void] WhyNoBox() {
		# if box doesn't exist, find out why:
		if (!$this.GetList('from Script') -or !$this.MakeNewBox()) {
			# if there's no requested varList in the script OR
			# I don't have write perms to cfgbox dir => Skip this script
			$this.CanSkip = $true
			return 
		}
		# now that you got a list and made a new box,
		#  update List to get timestamps into it
		$this.UpdateList()
	}
	[bool] MakeNewBox() {
		ni $this.Box.Path -Force
		if (Test-Path $this.Box.Path) {
			$this.Box.SetContent('#' + '1' * 3 * [cfgInfo]::timeFormat.Length + "`n")
			$this.Box = [File]::new($this.Box.Path)
			return $true
		}
		return $false
	}
	[string[]] CleanupList([string[]] $List) {
		if ($List.count -ne 0) {
			return (($List -replace '[^\s\w\d_]'
				).trim() | ? {
					$_.length -gt 0
				}) -replace ' ', '_'
		}
		return @()
	}
	[string[]] GetList([bool]$FromScript) {
		# check if varList already retrieved
		if ($this.GotList) { return $this.varList }
        
		# getList from Box when possible
		if (!$FromScript) {
			$List = &$this.Box.Path
			$this.varList = $this.CleanupList($List.Keys)
			if ($this.varList) {
				$this.GotList = $true 
				return $this.varList 
			}
		}
		# find cfgManCall in the script
		[string[]] $List = @()
		$this.ScriptParsed = $true		
		if ($slice = $this.Script.GetContent() | sls ('^(.*\n)*.*' + [cfgInfo]::callPattern + '[^\n]*$')) {
			# execute lines until the cfgMan call to get the varlist from script content
			iex($slice.Matches.Groups[0].Value -ireplace [cfgInfo]::callPattern, '$List =') 2>&1>$null
			$this.Script.DropContent()
		}
		$this.varList = $this.CleanupList($List)
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
		[cfgInfo]::newRoll = [cfgInfo]::oldRoll = [hashtable]::new((&([cfgInfo]::Roll.Path)), [System.StringComparer]::CurrentCultureIgnoreCase)
		[cfgInfo]::GotRoll = $true
		return [cfgInfo]::oldRoll
	}
	[void] UpdateList() {
		# get varList from script
		[string[]] $List = $this.GetList('from Script')
		[string[]]$cfgRoll = $this.GetRoll().Keys
        
		# [1] find new vars to add to cfgRoll
		# using cmdlets, easy but pipelined and does extra work, thus slow
		# $diff = diff $List $cfgRoll.Keys
		# $diff = $diff | ? -Property SideIndicator -eq '<=' 
		# $diff = $diff | select -ExpandProperty InputObject
        
		# simple O(nlogn) lookup, still faster than diff cmdlet method above
		[string[]] $diffs = @()
		foreach ($v in $List) { if ($cfgRoll -notcontains $v) { $diffs += $v } }
		# check if any new vars found
		if ($diffs.count -ne 0) {
			# mark for Value update
			$this.PendingValues = $true
			# add new vars to cfgRoll, no overwriting
			foreach ($v in $diffs) { [cfgInfo]::newRoll.Add($v, '') }
			# write to cfgRoll and cfgBox
			if (!$this.CommitToRoll()) { return }
			# also note down Script's write time as ack of vars found
			if (!$this.CommitToBoxAndBump('Script')) { return }
		}
		else {
			# also note down Script's write time as ack of changes processed
			if (!$this.BumpScript()) { return }
		}
		# mark List updated
		$this.PendingList = $false
	}
	[void] UpdateValues() {
		# find any undefined vars
		if ($this.FindUndefs()) { return }
		# if all vars are defined, merge values to box
		# and note cfgRoll's last write time as ack of values updated
		if (!$this.CommitToBoxAndBump('Roll')) { return }
		# mark Values update done
		$this.PendingValues = $false
	}
	[bool] FindUndefs() {
		# get varList from box
		[string[]] $List = $this.GetList('')
		[hashtable]$cfgRoll = $this.GetRoll()
		# Values are always strings or arrays of strings in cfgRoll
		#  So, casting to bool is essentially a check to see if
		#  there are any non-empty strings in the value
		foreach ($v in $List) { if (!$cfgRoll.Item($v)) { return $true } }
		return $false
	}
	[bool] DetectDesync() {
		$len = [cfgInfo]::timeFormat.Length
		$off = 1
		$header = $this.Box.GetContent().Substring($off, 3 * $len)
		$scriptStamp = $header.Substring(0, $len)
		$rollStamp = $header.Substring($len, $len)
		$boxStamp = [datetime]::ParseExact($header.Substring(2 * $len, $len), [cfgInfo]::timeFormat, $null)
		$flag = $false
		if ($scriptStamp -ne $this.Script.Time) { $this.PendingList = $true; $flag = $true }
		if ($boxStamp -lt [datetime]::ParseExact($this.Box.Time, [cfgInfo]::timeFormat, $null) -or 
			$rollStamp -ne [cfgInfo]::Roll.Time) { $this.PendingValues = $true; $flag = $true }
		return $flag
	}
	[string] ArrayToCodeString([string[]]$arr, [uint16]$lvl) {
		if ($lvl -lt 2) { $lvl = 2 }
		[string] $code = "@("
		foreach ($str in $arr) {
			$code += "`n" + ' ' * 4 * $lvl + ','
			if ($str -is [array]) {
				$code += $this.ArrayToCodeString($str, $lvl + 1)
				continue
			}
			$code += "'" + $str + "'"
		}
		$code += "`n" + ' ' * 4 * ($lvl - 1) + ')'
		return $code
	}
	[string] RollToCodeString([string[]]$keys, [hashtable]$roll) {
		[string] $code = "[ordered]@{"
		foreach ($key in $keys | sort) {
			$code += "`n" + ' ' * 4
			$code += "'" + $key + "' = "
			$value = $roll[$key]
			if ($value -is [Array]) {
				$code += $this.ArrayToCodeString($value, 0) + ';'
				continue
			}
			$code += "'" + $value + "';"
		}
		$code += "`n}"
		return $code
	}
	[bool] CommitToBoxAndBump([string] $bumpFile) {
		# This code should be unreachable if varList is not found or is empty so,
		# it's okay to use varList directly, skips a branch
		[string] $boxContent = $this.RollToCodeString($this.varList, [cfgInfo]::newRoll)
        
		# Now for the Bump...
		$len = [cfgInfo]::timeFormat.Length
		$off = 1
		[string] $header = $this.Box.GetContent()
		# [string] $header=[string]::new()
		if ($bumpFile -eq 'Script') {
			$header = $header.Substring($off + $len, $len)
			$header = $this.Script.Time + $header
		}
		elseif ($bumpFile -eq 'Roll') {
			$header = $header.Substring($off, $len)
			$header += [cfgInfo]::Roll.Time
		}
		else { $header = $header.Substring($off, 2 * $len) }
		$header = '#' + $header
        
		$boxContent = $header + (Get-Date).AddSeconds(7).ToUniversalTime().ToString([cfgInfo]::timeFormat) + "`n" + $boxContent
		return $this.Box.SetContent($boxContent)
	}
	[bool] BumpScript() {
		$len = [cfgInfo]::timeFormat.Length
		$off = 1
		[string] $boxContent = $this.Box.GetContent()
		[string] $header = '#' + $this.Script.Time + $boxContent.Substring($off + $len, $len)
        
		$boxContent = $boxContent.Substring($off + 3 * $len)
		$boxContent = $header + (Get-Date).AddSeconds(7).ToUniversalTime().ToString([cfgInfo]::timeFormat) + $boxContent
		return $this.Box.SetContent($boxContent)
	}
	[bool] CommitToRoll() {
		# This code should be unreachable if varList is not found or is empty so,
		# it's okay to use varList directly, skips a branch
		[string] $rollContent = $this.RollToCodeString([cfgInfo]::newRoll.Keys, [cfgInfo]::newRoll)
		if ([cfgInfo]::Roll.SetContent($rollContent)) {
			[cfgInfo]::GotRoll = $false
			return $true
		}
		return $false
	}
	[void] SetVars() {
		if (!$this.Ready) { return }
		$boxRoll = &($this.Box.path)
		foreach ($var in $boxRoll.Keys) {
			sv -Scope Script -Name $var -Value $this.EvalArr($boxRoll[$var])
		}
	}
	[string[]] EvalArr([string[]]$arr) {
		if (!$this.Ready) { return '' }
		[string[]]$values = @()
		foreach ($value in $arr) {
			if ($value -is [Array]) { $values += EvalArr($value) }
			else {
				$v = $value -replace '"', '`"'
				$v = iex "echo `"$value`""
				$values += $v
			}
		}
		return $values
	}
}
Class File {
	[string] $Path
	[bool] $Missing = $true
	[bool] $GotContent = $false
	[System.IO.FileSystemInfo]$FSI
	[string] hidden $Content
	[string]$Time
    
	File ([string] $path) {
		if (!$path) { return }
		$this.path = $path
		if (!(Test-Path $path)) { return }
		$this.FSI = gi $path
		$this.Path = $this.FSI.FullName
		$this.Missing = !($this.FSI.Exists -and $this.FSI.Directory)
		$this.Time = $this.FSI.LastWriteTimeUtc.ToString([cfgInfo]::timeFormat)
	}
	File ([System.IO.FileSystemInfo] $FSI) {
		$this.FSI = $FSI
		$this.Path = $this.FSI.FullName
		if ($this.FSI.Exists) {
			$this.Missing = !($this.FSI.Exists -and $this.FSI.Directory)
			$this.Time = $this.FSI.LastWriteTimeUtc.ToString([cfgInfo]::timeFormat)
		}
	}
	[string] GetContent() {
		if ($this.Missing) { return '' }
		if (!$this.GotContent) { $this.RefreshContent() }
		return $this.Content    
	}
	[string] RefreshContent() {
		if ($this.Missing) { return '' }
		$this.Content = gc $this.Path -Raw
		if ($this.Content.length) { $this.GotContent = $true }
		else { $this.GotContent = $false }
		return $this.Content
	}
	[bool] SetContent([string] $newContent) {
		if ($this.Missing) { return '' }
		$success = [bool](sc -Path $this.Path -Value $newContent -PassThru)
		if ($success) {
			$this.GotContent = $true
			$this.Content = $newContent
			if ($this.FSI.Exists) {
				$this.FSI.Refresh()
				$this.Time = $this.FSI.LastWriteTimeUtc.ToString([cfgInfo]::timeFormat)
			}
		}
		return $success        
	}
	[void] DropContent() {
		if ($this.Missing) { return }
		$this.Content = [string]::new('')
		$this.GotContent = $false
	}
}

if ($get) {
	[cfgInfo]::new($get).SetVars()
	return
}

function ProcessBox([string]$path) {
	'processing: ' + $path
	$item = [cfgInfo]::new($path)
	if ($item.ScriptParsed) { 'Script had to be Parsed' }
	if ($item.varList) {
		'Secrets requested:'
		$item.varList
	}
	if ($item.CanSkip) { 'Skipped' }
	elseif ($item.Ready) { 'Box is updated' }else {
		'Updates to cfgRoll pending: ' + $item.PendingList
		'Updates to cfgBox pending: ' + $item.PendingValues
	}
	''
}

if ($path) {
	if ($parse) {
		$item = [cfgInfo]::new($path)
		if (!$item.ScriptParsed) {
			$item.GetList('from Script')
		}
		return
	}
	ProcessBox($path)
	return
}

$scripts = gci -recurse *.ps1 -exclude *.cfgbox.ps1 
foreach ($s in $scripts) { ProcessBox($s) }