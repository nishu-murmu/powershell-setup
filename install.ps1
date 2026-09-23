<#
.SYNOPSIS
    One-command bootstrap for this Windows Terminal / PowerShell setup.

.DESCRIPTION
    Installs everything this repository's $PROFILE needs. Every step is
    idempotent, so the script can be re-run safely at any time.

      1. winget (App Installer)     - bootstrapped from Microsoft when missing
      2. scoop                      - https://get.scoop.sh
      3. Git, fzf, ripgrep          - fzf/ripgrep through scoop (winget fallback)
      4. Oh My Posh, PowerShell 7,
         Neovim, Windows Terminal   - through winget, skipped when already present
      5. Hack Nerd Font             - official nerd-fonts release, installed per user
      6. PowerShell modules         - posh-git, Terminal-Icons, PSFzf and PSReadLine,
                                       installed for BOTH PowerShell 5.1 and PowerShell 7
      7. $PROFILE                   - one managed block written for both shells
      8. Windows Terminal font      - only configured when no font is set yet

    Administrator rights are not required. winget may still raise a UAC prompt
    for machine wide packages such as Git.

.EXAMPLE
    irm https://raw.githubusercontent.com/nishu-murmu/powershell-setup/main/install.ps1 | iex

.EXAMPLE
    # development branch - experimental changes, testing only
    irm https://raw.githubusercontent.com/nishu-murmu/powershell-setup/dev/install.ps1 | iex
#>
& {
    $ErrorActionPreference = 'Continue'
    $ProgressPreference = 'SilentlyContinue'
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch { }

    $State = @{ Failures = New-Object 'System.Collections.Generic.List[string]' }

    # ------------------------------------------------------------------ output
    function Write-Step([string]$Message) { Write-Host ('' + [char]10 + '>> ' + $Message) -ForegroundColor Cyan }
    function Write-OK([string]$Message)   { Write-Host ('   [ok] ' + $Message) -ForegroundColor Green }
    function Write-Info([string]$Message) { Write-Host ('        ' + $Message) -ForegroundColor DarkGray }
    function Write-Warn([string]$Message) { Write-Host ('   [!] ' + $Message) -ForegroundColor Yellow }
    function Write-Fail([string]$Message) { $State.Failures.Add($Message); Write-Host ('   [FAIL] ' + $Message) -ForegroundColor Red }

    # ----------------------------------------------------------------- helpers
    function Test-Command([string]$Name) {
        return [bool](Get-Command -Name $Name -ErrorAction SilentlyContinue | Select-Object -First 1)
    }

    function Update-SessionPath {
        # Merge the PATH from the registry into this session without dropping
        # anything that only exists here - picks up shims created earlier in
        # this run (scoop, oh-my-posh, ...) even when the session inherited a
        # stale PATH from its parent process.
        $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
        $user = [Environment]::GetEnvironmentVariable('Path', 'User')
        $parts = @()
        if ($machine) { $parts += $machine }
        if ($user) { $parts += $user }
        if ($parts.Count -eq 0) { return }

        $fresh = @(([Environment]::ExpandEnvironmentVariables(($parts -join ';'))) -split ';' |
                   Where-Object { $_ -and $_.Trim() })
        $current = @($env:Path -split ';' | Where-Object { $_ -and $_.Trim() })
        $changed = $false
        foreach ($entry in $fresh) {
            if ($current -notcontains $entry) { $current += $entry; $changed = $true }
        }
        if ($changed) { $env:Path = ($current -join ';') }
    }

    function Get-ScoopRoot {
        if ($env:SCOOP) { return $env:SCOOP }
        return (Join-Path $HOME 'scoop')
    }

    function Test-ScoopInstalled {
        if (Test-Command 'scoop') { return $true }
        $shims = Join-Path (Get-ScoopRoot) 'shims'
        return ((Test-Path -LiteralPath (Join-Path $shims 'scoop.ps1')) -or
                (Test-Path -LiteralPath (Join-Path $shims 'scoop.cmd')))
    }

    function Test-IsAdministrator {
        try {
            $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
            $principal = New-Object Security.Principal.WindowsPrincipal($identity)
            return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        } catch { return $false }
    }

    # ------------------------------------------------------------------ winget
    function Install-Winget {
        if (Test-Command 'winget') { Write-OK 'winget is available'; return $true }
        Write-Info 'bootstrapping winget (App Installer) from Microsoft'
        $bundle = Join-Path $env:TEMP 'getwinget.msixbundle'
        try {
            Invoke-WebRequest -Uri 'https://aka.ms/getwinget' -OutFile $bundle -UseBasicParsing -ErrorAction Stop
            Add-AppxPackage -Path $bundle -ErrorAction Stop
            Update-SessionPath
        } catch {
            Write-Warn $_.Exception.Message
        } finally {
            Remove-Item -LiteralPath $bundle -Force -ErrorAction SilentlyContinue
        }
        if (Test-Command 'winget') { Write-OK 'winget installed'; return $true }
        Write-Fail 'winget is not available. Install "App Installer" from the Microsoft Store (https://aka.ms/getwinget) and re-run this script'
        return $false
    }

    function Install-WingetPackage {
        param([string]$Id, [string]$Detect)

        if ($Detect -and (Test-Command $Detect)) { Write-OK "$Detect is already installed"; return }
        if (-not (Test-Command 'winget')) { Write-Warn "skipping $Id (winget unavailable)"; return }

        Write-Info "winget install $Id"
        & winget install --id $Id --exact --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
        if ($LASTEXITCODE -ne 0) {
            Write-Info 'retrying without --disable-interactivity'
            & winget install --id $Id --exact --source winget --accept-package-agreements --accept-source-agreements
        }

        Update-SessionPath
        if ($Detect) {
            if (Test-Command $Detect) { Write-OK "$Detect installed"; return }
            Write-Fail "$Id could not be installed. Run this terminal as Administrator and re-run the script, or install $Id manually"
            return
        }
        if ($LASTEXITCODE -eq 0) { Write-OK "$Id installed" } else { Write-Fail "$Id could not be installed" }
    }

    # ------------------------------------------------------------------- scoop
    function Install-Scoop {
        Update-SessionPath
        if (Test-ScoopInstalled) {
            if (Test-Command 'scoop') { Write-OK 'scoop is already installed'; return $true }
            Write-Warn 'scoop is installed but not reachable on PATH - open a new terminal, winget is used as fallback here'
            return $false
        }

        # scoop needs a policy that allows local scripts
        $allowed = @('RemoteSigned', 'Unrestricted', 'ByPass')
        $effective = (Get-ExecutionPolicy).ToString()
        if ($allowed -contains $effective) {
            Write-Info "execution policy already allows local scripts ($effective)"
        } else {
            try {
                Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
                Write-Info 'set the current-user execution policy to RemoteSigned'
            } catch {
                Write-Warn ("execution policy: " + $_.Exception.Message)
            }
        }

        Write-Info 'installing scoop from https://get.scoop.sh'
        # The installer is run in a child process on purpose: when it refuses to
        # continue (already installed, started as administrator, ...) it calls
        # `break`, which would silently terminate this whole script.
        & powershell.exe -NoProfile -NonInteractive -Command "Invoke-RestMethod -Uri 'https://get.scoop.sh' -ErrorAction Stop | Invoke-Expression"
        Update-SessionPath

        if (Test-Command 'scoop') { Write-OK 'scoop installed'; return $true }
        if (Test-ScoopInstalled) {
            Write-Warn 'scoop is installed but not reachable on PATH - open a new terminal, winget is used as fallback here'
            return $false
        }
        if (Test-IsAdministrator) {
            Write-Fail 'scoop refuses to install from an elevated terminal - re-run this script without Administrator rights'
        } else {
            Write-Fail 'scoop could not be installed'
        }
        return $false
    }

    function Install-ScoopPackage {
        param([string]$Name, [string]$Detect, [string]$FallbackWingetId)

        if ($Detect -and (Test-Command $Detect)) { Write-OK "$Detect is already installed"; return }

        if (Test-Command 'scoop') {
            $scoopRoot = Get-ScoopRoot
            if (-not (Test-Path -LiteralPath (Join-Path (Join-Path $scoopRoot 'buckets') 'main'))) {
                Write-Info "adding the scoop 'main' bucket"
                & scoop bucket add main *> $null
            }
            Write-Info "scoop install $Name"
            & scoop install $Name
            Update-SessionPath
            if ($Detect -and (Test-Command $Detect)) { Write-OK "$Detect installed through scoop"; return }
        }

        if ($FallbackWingetId) {
            Write-Info "falling back to winget for $FallbackWingetId"
            Install-WingetPackage -Id $FallbackWingetId -Detect $Detect
            return
        }
        Write-Fail "$Name could not be installed"
    }

    # ------------------------------------------------------------------- fonts
    function Ensure-FontDirectoryAcl {
        param([string]$Directory)
        try {
            $acl = Get-Acl -LiteralPath $Directory
            $names = @($acl.Access | ForEach-Object { $_.IdentityReference.Value })
            $missingSids = @()
            if (-not ($names -match 'ALL APPLICATION PACKAGES')) { $missingSids += 'S-1-15-2-1' }
            if (-not ($names -match 'ALL RESTRICTED APPLICATION PACKAGES')) { $missingSids += 'S-1-15-2-2' }
            if ($missingSids.Count -eq 0) { return }
            foreach ($sidText in $missingSids) {
                $sid = [System.Security.Principal.SecurityIdentifier]$sidText
                $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
                    $sid, 'ReadAndExecute', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
                $acl.SetAccessRule($rule)
            }
            Set-Acl -LiteralPath $Directory -AclObject $acl -ErrorAction Stop
            Write-Info 'added the missing permissions on the user font folder'
        } catch {
            Write-Warn ("font folder permissions: " + $_.Exception.Message)
        }
    }

    function Install-HackNerdFont {
        $fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
        $regPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
        $required = @('HackNerdFont-Regular.ttf', 'HackNerdFont-Bold.ttf',
                      'HackNerdFont-Italic.ttf', 'HackNerdFont-BoldItalic.ttf')
        $missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $fontDir $_)) })

        $tmp = $null
        $sourceDir = $fontDir
        try {
            if ($missing.Count -gt 0) {
                $tmp = Join-Path $env:TEMP ('hack-nerd-font-' + [Guid]::NewGuid().ToString('N'))
                New-Item -ItemType Directory -Path $tmp -Force | Out-Null
                $zip = Join-Path $tmp 'Hack.zip'
                $url = 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip'
                Write-Info "downloading Hack Nerd Font from $url"
                Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -ErrorAction Stop
                $unzip = Join-Path $tmp 'extracted'
                Expand-Archive -LiteralPath $zip -DestinationPath $unzip -Force -ErrorAction Stop
                $sourceDir = $unzip
            }

            $files = @(Get-ChildItem -LiteralPath $sourceDir -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object {
                    ($_.Extension -ieq '.ttf' -or $_.Extension -ieq '.otf') -and
                    $_.Name -like 'Hack*' -and
                    $_.Name -notmatch 'Windows Compatible|Mac Compatible'
                })
            if ($files.Count -eq 0) { throw 'no Hack font files were found' }

            if (-not (Test-Path -LiteralPath $fontDir)) { New-Item -ItemType Directory -Path $fontDir -Force | Out-Null }
            Ensure-FontDirectoryAcl -Directory $fontDir

            $registered = @{}
            $key = Get-Item -Path $regPath
            foreach ($name in $key.GetValueNames()) {
                $value = $key.GetValue($name)
                if ($value) { $registered[$value.ToString().ToLower()] = $name }
            }

            $registeredNow = 0
            foreach ($file in $files) {
                $dest = Join-Path $fontDir $file.Name

                if ($sourceDir -ne $fontDir) {
                    $needCopy = -not (Test-Path -LiteralPath $dest)
                    if (-not $needCopy -and (Get-Item -LiteralPath $dest).Length -ne $file.Length) { $needCopy = $true }
                    if ($needCopy) {
                        try {
                            Copy-Item -LiteralPath $file.FullName -Destination $dest -Force -ErrorAction Stop
                        } catch {
                            Write-Warn ("could not replace " + $file.Name + " (file in use?) - keeping the installed copy")
                        }
                    }
                }

                if (-not (Test-Path -LiteralPath $dest)) { continue }
                $destKey = $dest.ToLower()
                if ($registered.ContainsKey($destKey)) { continue }

                $kind = 'TrueType'
                if ($file.Extension -ieq '.otf') { $kind = 'OpenType' }
                $valueName = [IO.Path]::GetFileNameWithoutExtension($file.Name) + ' (' + $kind + ')'
                try {
                    New-ItemProperty -Path $regPath -Name $valueName -Value $dest -PropertyType String -Force -ErrorAction Stop | Out-Null
                    $registered[$destKey] = $valueName
                    $registeredNow++
                } catch {
                    Write-Warn ("font registration: " + $_.Exception.Message)
                }
            }

            if ($missing.Count -eq 0 -and $registeredNow -eq 0) {
                Write-OK 'Hack Nerd Font is already installed'
            } else {
                Write-OK ("Hack Nerd Font: {0} files installed, {1} newly registered" -f $files.Count, $registeredNow)
            }
        } catch {
            Write-Fail ("Hack Nerd Font: " + $_.Exception.Message)
        } finally {
            if ($tmp -and (Test-Path -LiteralPath $tmp)) {
                Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # ---------------------------------------------------------- ps environment
    function Get-HostTargets {
        $docs = [Environment]::GetFolderPath('MyDocuments')
        $currentIsWindowsPowerShell = ($PSVersionTable.PSVersion.Major -lt 6)

        $winPsProfile = Join-Path (Join-Path $docs 'WindowsPowerShell') 'Microsoft.PowerShell_profile.ps1'
        $pwshProfile = Join-Path (Join-Path $docs 'PowerShell') 'Microsoft.PowerShell_profile.ps1'
        if ($currentIsWindowsPowerShell) { $winPsProfile = $PROFILE } else { $pwshProfile = $PROFILE }

        $pwshSystemPath = $null
        if ($env:ProgramFiles) { $pwshSystemPath = Join-Path $env:ProgramFiles 'PowerShell\Modules' }

        $targets = @()
        $targets += [pscustomobject]@{
            Name        = 'Windows PowerShell 5.1'
            Current     = $currentIsWindowsPowerShell
            Exists      = $true
            Exe         = 'powershell.exe'
            ProfilePath = $winPsProfile
            ModulePath  = Join-Path (Join-Path $docs 'WindowsPowerShell') 'Modules'
            SystemPath  = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\Modules'
        }
        $targets += [pscustomobject]@{
            Name        = 'PowerShell 7'
            Current     = -not $currentIsWindowsPowerShell
            Exists      = [bool](Get-Command pwsh -ErrorAction SilentlyContinue)
            Exe         = 'pwsh'
            ProfilePath = $pwshProfile
            ModulePath  = Join-Path (Join-Path $docs 'PowerShell') 'Modules'
            SystemPath  = $pwshSystemPath
        }
        return $targets
    }

    function Test-ModuleVisible {
        param([string]$ModuleName, $Target)

        if (-not $Target.Exists) { return $true }
        if ($Target.Current) {
            return [bool](Get-Module -ListAvailable -Name $ModuleName | Select-Object -First 1)
        }
        foreach ($base in @($Target.ModulePath, $Target.SystemPath)) {
            if (-not $base) { continue }
            $dir = Join-Path $base $ModuleName
            if (Test-Path -LiteralPath $dir) {
                $manifest = Get-ChildItem -LiteralPath $dir -Recurse -Depth 3 -Filter '*.psd1' -ErrorAction SilentlyContinue |
                    Select-Object -First 1
                if ($manifest) { return $true }
            }
        }
        return $false
    }

    function Install-NuGetProvider {
        $provider = Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue |
            Sort-Object Version -Descending | Select-Object -First 1
        if ($provider -and $provider.Version -ge [version]'2.8.5.201') {
            Write-OK ("NuGet provider " + $provider.Version + ' is available')
            return $true
        }

        Write-Info 'installing the NuGet package provider (required by the PowerShell Gallery)'
        try {
            Install-PackageProvider -Name NuGet -MinimumVersion '2.8.5.201' -Force -Scope CurrentUser -ErrorAction Stop | Out-Null
        } catch {
            Write-Warn $_.Exception.Message
            try {
                Install-PackageProvider -Name NuGet -MinimumVersion '2.8.5.201' -Force -ErrorAction Stop | Out-Null
            } catch {
                Write-Warn $_.Exception.Message
            }
        }

        $provider = Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue |
            Sort-Object Version -Descending | Select-Object -First 1
        if ($provider -and $provider.Version -ge [version]'2.8.5.201') {
            Write-OK ("NuGet provider " + $provider.Version + ' installed')
            return $true
        }
        Write-Fail 'the NuGet package provider could not be installed - PowerShell modules are skipped'
        return $false
    }

    function Enable-TrustedGallery {
        try {
            $repo = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
            if ($repo -and $repo.InstallationPolicy -ne 'Trusted') {
                Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop | Out-Null
                Write-Info 'the PowerShell Gallery is now trusted (no more prompts)'
            }
        } catch {
            Write-Info 'the PowerShell Gallery stays untrusted - installs use -Force to skip prompts'
        }
    }

    function Install-ModuleForTarget {
        param([string]$ModuleName, $Target)

        if ($Target.Current) {
            Install-Module -Name $ModuleName -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
            return
        }
        $command = "Install-Module -Name '$ModuleName' -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop"
        & $Target.Exe -NoProfile -NonInteractive -Command $command
        if ($LASTEXITCODE -ne 0) { throw "$($Target.Exe) exited with code $LASTEXITCODE" }
    }

    function Install-PSModule {
        param([string]$Name)

        foreach ($target in (Get-HostTargets)) {
            if (-not $target.Exists) { continue }
            if (Test-ModuleVisible -ModuleName $Name -Target $target) {
                Write-OK "$Name is available for $($target.Name)"
                continue
            }
            Write-Info "installing $Name for $($target.Name)"
            try {
                Install-ModuleForTarget -ModuleName $Name -Target $target
                if (Test-ModuleVisible -ModuleName $Name -Target $target) {
                    Write-OK "$Name installed for $($target.Name)"
                } else {
                    Write-Fail "$Name did not end up in the module path of $($target.Name)"
                }
            } catch {
                Write-Fail ("$Name ($($target.Name)): " + $_.Exception.Message)
            }
        }
    }

    function Install-PsReadLineForWindowsPowerShell {
        $winPs = Get-HostTargets | Where-Object { $_.Name -eq 'Windows PowerShell 5.1' } | Select-Object -First 1
        if (-not $winPs -or -not $winPs.Exists) { return }

        $query = 'Import-Module PSReadLine -Force -ErrorAction Stop; (Get-Module PSReadLine).Version.ToString()'
        $readVersion = {
            $result = $null
            $output = & powershell.exe -NoProfile -NonInteractive -Command $query
            if ($output) {
                $text = ($output | Select-Object -Last 1).ToString().Trim()
                $parsed = $null
                if ([version]::TryParse($text, [ref]$parsed)) { $result = $parsed }
            }
            return $result
        }

        $current = & $readVersion
        if ($current -and $current -ge [version]'2.1.0') {
            Write-OK ("PSReadLine " + $current + ' is already available for Windows PowerShell')
            return
        }

        Write-Info 'installing PSReadLine for Windows PowerShell (needed for -PredictionSource History)'
        $userModuleDir = Join-Path $winPs.ModulePath 'PSReadLine'
        $before = @()
        if (Test-Path -LiteralPath $userModuleDir) {
            $before = @(Get-ChildItem -LiteralPath $userModuleDir -Directory | ForEach-Object Name)
        }

        try {
            Install-ModuleForTarget -ModuleName 'PSReadLine' -Target $winPs
        } catch {
            Write-Fail ("PSReadLine (Windows PowerShell): " + $_.Exception.Message)
            return
        }

        $verified = & $readVersion
        if ($verified -and $verified -ge [version]'2.1.0') {
            Write-OK ("PSReadLine " + $verified + ' installed for Windows PowerShell')
            return
        }

        # Windows PowerShell cannot load the installed copy: roll back so the shell
        # keeps working with its built-in PSReadLine.
        if (Test-Path -LiteralPath $userModuleDir) {
            foreach ($dir in @(Get-ChildItem -LiteralPath $userModuleDir -Directory -ErrorAction SilentlyContinue)) {
                if ($before -notcontains $dir.Name) {
                    Remove-Item -LiteralPath $dir.FullName -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
        Write-Fail 'PSReadLine for Windows PowerShell could not be verified and was rolled back'
    }

    # --------------------------------------------------------- windows terminal
    function Set-WindowsTerminalFont {
        param([string]$Face)

        $candidates = @(
            (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
            (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
        )
        $file = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
        if (-not $file) { Write-Warn 'Windows Terminal settings.json not found - font not configured'; return }

        try {
            $json = [IO.File]::ReadAllText($file) | ConvertFrom-Json -ErrorAction Stop
        } catch {
            Write-Warn 'Windows Terminal settings.json could not be parsed (comments?) - left untouched'
            return
        }

        $defaults = $null
        if ($json.PSObject.Properties['profiles'] -and $json.profiles -and
            $json.profiles.PSObject.Properties['defaults']) {
            $defaults = $json.profiles.defaults
        }
        if ($defaults -and $defaults.PSObject.Properties['font'] -and
            $defaults.font -is [pscustomobject] -and $defaults.font.PSObject.Properties['face'] -and
            $defaults.font.face) {
            if ($defaults.font.face -eq $Face) {
                Write-OK "Windows Terminal already uses the '$Face' font"
            } else {
                Write-OK "Windows Terminal font is set to '$($defaults.font.face)' - not changed"
            }
            return
        }

        try {
            if (-not $json.PSObject.Properties['profiles']) {
                $json | Add-Member -NotePropertyName profiles -NotePropertyValue (New-Object PSObject)
            }
            if (-not $json.profiles.PSObject.Properties['defaults']) {
                $json.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue (New-Object PSObject)
            }
            $defaults = $json.profiles.defaults
            if ($defaults.PSObject.Properties['fontFace']) { $defaults.PSObject.Properties.Remove('fontFace') }

            $fontObject = $null
            if ($defaults.PSObject.Properties['font'] -and $defaults.font -is [pscustomobject]) {
                $fontObject = $defaults.font
            } else {
                $fontObject = New-Object PSObject
                $defaults | Add-Member -NotePropertyName font -NotePropertyValue $fontObject
            }
            if ($fontObject.PSObject.Properties['face']) { $fontObject.face = $Face }
            else { $fontObject | Add-Member -NotePropertyName face -NotePropertyValue $Face }

            $backup = $file + '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
            Copy-Item -LiteralPath $file -Destination $backup -Force
            $utf8 = New-Object System.Text.UTF8Encoding($false)
            [IO.File]::WriteAllText($file, ($json | ConvertTo-Json -Depth 50), $utf8)
            Write-OK "Windows Terminal default font set to '$Face'"
        } catch {
            Write-Warn ("Windows Terminal settings: " + $_.Exception.Message)
        }
    }

    # ------------------------------------------------------------------ profile
    function Get-ProfileBlock {
        $block = @'
# >>> powershell-setup:managed-block >>>
# Generated by install.ps1 - edits inside this block are overwritten.

# Oh My Posh prompt
$psuOmp = Get-Command oh-my-posh -ErrorAction SilentlyContinue
if ($psuOmp) {
    try {
        if ([Console]::OutputEncoding.WebName -ne 'utf-8') { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 }
        $psuThemes = $env:POSH_THEMES_PATH
        if (-not $psuThemes) { $psuThemes = Join-Path $env:LOCALAPPDATA 'Programs\oh-my-posh\themes' }
        $psuConfig = Join-Path $psuThemes 'robbyrussell.omp.json'
        if (Test-Path -LiteralPath $psuConfig) {
            oh-my-posh init pwsh --config $psuConfig | Invoke-Expression
        } else {
            oh-my-posh init pwsh | Invoke-Expression
        }
    } catch {
        Write-Warning ('oh-my-posh: ' + $_.Exception.Message)
    }
}

# Git status in the prompt and file icons everywhere
Import-Module posh-git -ErrorAction SilentlyContinue
Import-Module Terminal-Icons -ErrorAction SilentlyContinue

# PSReadLine
try {
    $psuPsrl = Import-Module PSReadLine -PassThru -ErrorAction Stop
    Set-PSReadLineOption -EditMode Emacs -BellStyle None
    if ($psuPsrl.Version -ge [version]'2.1.0') {
        # needs a console with virtual terminal support - silent when redirected
        Set-PSReadLineOption -PredictionSource History -ErrorAction SilentlyContinue
    }
    Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
} catch { }

# fzf (Ctrl+f file picker, Ctrl+r reverse history)
if ((Get-Command fzf -CommandType Application -ErrorAction SilentlyContinue) -and (Get-Module -ListAvailable -Name PSFzf)) {
    try {
        Import-Module PSFzf -ErrorAction Stop
        Set-PSFzfOption -PSReadlineChordProvider 'Ctrl+f' -PSReadlineChordReverseHistory 'Ctrl+r'
    } catch { }
}

# Aliases
Set-Alias -Name ll -Value ls
Set-Alias -Name grep -Value findstr
if (Get-Command git -ErrorAction SilentlyContinue) { Set-Alias -Name g -Value git }
if (Get-Command nvim -ErrorAction SilentlyContinue) { Set-Alias -Name vim -Value nvim }
$psuGitCmd = Get-Command git -ErrorAction SilentlyContinue
$psuGitRoot = $null
if ($psuGitCmd -and $psuGitCmd.CommandType -eq 'Application') {
    $psuCandidate = Split-Path -Parent (Split-Path -Parent $psuGitCmd.Source)
    if (Test-Path -LiteralPath (Join-Path $psuCandidate 'usr\bin')) { $psuGitRoot = $psuCandidate }
    elseif (Test-Path -LiteralPath 'C:\Program Files\Git\usr\bin') { $psuGitRoot = 'C:\Program Files\Git' }
}
if ($psuGitRoot) {
    $psuTig = Join-Path $psuGitRoot 'usr\bin\tig.exe'
    $psuLess = Join-Path $psuGitRoot 'usr\bin\less.exe'
    if (Test-Path -LiteralPath $psuTig) { Set-Alias -Name tig -Value $psuTig }
    if (Test-Path -LiteralPath $psuLess) { Set-Alias -Name less -Value $psuLess }
}

# Utilities
function which ($command) {
    Get-Command -Name $command -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
}
# <<< powershell-setup:managed-block <<<
'@
        return ($block -replace "`r`n|`n", "`r`n")
    }

    function Update-Profile {
        param([string]$Path, [string]$Block)

        $beginMarker = '# >>> powershell-setup:managed-block >>>'
        $endMarker = '# <<< powershell-setup:managed-block <<<'

        $content = ''
        $exists = Test-Path -LiteralPath $Path
        if ($exists) { $content = [IO.File]::ReadAllText($Path) }

        $beginIndex = $content.IndexOf($beginMarker, [StringComparison]::Ordinal)
        $endIndex = $content.IndexOf($endMarker, [StringComparison]::Ordinal)

        if ($beginIndex -ge 0 -and $endIndex -gt $beginIndex) {
            $remainder = $content.Substring($endIndex + $endMarker.Length)
            if ($remainder.StartsWith("`r`n")) { $remainder = $remainder.Substring(2) }
            elseif ($remainder.StartsWith("`n")) { $remainder = $remainder.Substring(1) }
            $newContent = $content.Substring(0, $beginIndex) + $Block + $remainder
        } else {
            $separator = ''
            if ($content.Length -gt 0) {
                $separator = "`r`n"
                if (-not $content.EndsWith("`n")) { $separator = "`r`n`r`n" }
            }
            $newContent = $content + $separator + $Block
        }

        if ($content -eq $newContent) {
            Write-OK "$Path is up to date"
            return
        }

        try {
            if ($exists -and $content.Length -gt 0) {
                $backup = $Path + '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
                Copy-Item -LiteralPath $Path -Destination $backup -Force
            }
            $directory = Split-Path -Parent $Path
            if (-not (Test-Path -LiteralPath $directory)) {
                New-Item -ItemType Directory -Path $directory -Force | Out-Null
            }
            [IO.File]::WriteAllText($Path, $newContent, (New-Object System.Text.UTF8Encoding($true)))
            Write-OK "profile updated: $Path"
        } catch {
            Write-Fail ("profile " + $Path + ': ' + $_.Exception.Message)
        }
    }

    function Write-Summary {
        Write-Host ''
        Write-Host '======================================================' -ForegroundColor Magenta
        if ($State.Failures.Count -eq 0) {
            Write-Host ' Everything installed. ' -ForegroundColor Green
        } else {
            Write-Host (" Finished with {0} problem(s): " -f $State.Failures.Count) -ForegroundColor Yellow
            foreach ($failure in $State.Failures) { Write-Host ('  - ' + $failure) -ForegroundColor Yellow }
        }
        Write-Host '======================================================' -ForegroundColor Magenta
        Write-Host ' Next:' -ForegroundColor Cyan
        Write-Host '   1. Restart Windows Terminal - a new tab picks up the font and the profile.'
        Write-Host '   2. Change the theme by editing the robbyrussell.omp.json file name inside the'
        Write-Host '      managed block of your $PROFILE (Get-PoshThemes lists them all).'
        Write-Host ''
    }

    # --------------------------------------------------------------------- main
    Write-Host 'Windows Terminal + PowerShell setup' -ForegroundColor Magenta
    Write-Host ('PowerShell ' + $PSVersionTable.PSVersion + ' | user ' + $env:USERNAME) -ForegroundColor DarkGray
    if ($env:OS -ne 'Windows_NT') { Write-Fail 'this setup is for Windows only'; return }
    Update-SessionPath
    if (-not (Test-IsAdministrator)) {
        Write-Info 'not elevated: a UAC prompt can appear for machine-wide packages (Git, Neovim, ...)'
    }

    Write-Step 'Package managers'
    $hasWinget = Install-Winget
    $scoopReady = Install-Scoop

    Write-Step 'Command line tools'
    if ($hasWinget) { Install-WingetPackage -Id 'Git.Git' -Detect 'git' }
    if ($scoopReady) {
        Install-ScoopPackage -Name 'fzf' -Detect 'fzf' -FallbackWingetId 'junegunn.fzf'
        Install-ScoopPackage -Name 'ripgrep' -Detect 'rg' -FallbackWingetId 'BurntSushi.ripgrep.MSVC'
    } elseif ($hasWinget) {
        Install-WingetPackage -Id 'junegunn.fzf' -Detect 'fzf'
        Install-WingetPackage -Id 'BurntSushi.ripgrep.MSVC' -Detect 'rg'
    }

    Write-Step 'Applications'
    if ($hasWinget) {
        Install-WingetPackage -Id 'JanDeDobbeleer.OhMyPosh' -Detect 'oh-my-posh'
        Install-WingetPackage -Id 'Microsoft.PowerShell' -Detect 'pwsh'
        Install-WingetPackage -Id 'Neovim.Neovim' -Detect 'nvim'
        Install-WingetPackage -Id 'Microsoft.WindowsTerminal' -Detect 'wt'
    }

    Write-Step 'Fonts'
    Install-HackNerdFont

    Write-Step 'PowerShell modules'
    if (Install-NuGetProvider) {
        Enable-TrustedGallery
        Install-PsReadLineForWindowsPowerShell
        foreach ($module in 'posh-git', 'Terminal-Icons', 'PSFzf') {
            Install-PSModule -Name $module
        }
    }

    Write-Step 'Windows Terminal'
    Set-WindowsTerminalFont -Face 'Hack Nerd Font'

    Write-Step 'PowerShell profile'
    $block = Get-ProfileBlock
    $currentProfiles = @()
    foreach ($target in (Get-HostTargets)) {
        if (-not $target.Exists) { continue }
        Update-Profile -Path $target.ProfilePath -Block $block
        if ($target.Current) { $currentProfiles += $target.ProfilePath }
    }

    foreach ($profilePath in $currentProfiles) {
        if (Test-Path -LiteralPath $profilePath) {
            Write-Info ("applying " + $profilePath + ' to this session')
            try {
                . $profilePath
            } catch {
                Write-Warn ("could not apply the profile to this session: " + $_.Exception.Message)
            }
        }
    }

    Write-Summary
}
