<#
.SYNOPSIS
    Bootstrap script for Windows Terminal / PowerShell setup.

.DESCRIPTION
    Installs and configures:
      1. Applications (Git, Oh My Posh, fzf, ripgrep, Neovim, Windows Terminal) via winget
      2. Hack Nerd Font
      3. PowerShell modules (posh-git, Terminal-Icons, PSFzf, PSReadLine)
      4. Oh My Posh theme dynamically chosen and downloaded to:
         $env:LOCALAPPDATA\Programs\oh-my-posh\themes\<theme>.omp.json
      5. Windows Terminal default font
      6. PowerShell $PROFILE configuration (with fixed aliases and functions)

.EXAMPLE
    irm https://raw.githubusercontent.com/nishu-murmu/powershell-setup/main/install.ps1 | iex
#>

& {
    $ErrorActionPreference = 'Continue'
    $ProgressPreference = 'SilentlyContinue'

    function Write-Step([string]$msg) { Write-Host ("`n>> " + $msg) -ForegroundColor Cyan }
    function Write-OK([string]$msg)   { Write-Host ("   [ok] " + $msg) -ForegroundColor Green }
    function Write-Warn([string]$msg) { Write-Host ("   [!] " + $msg) -ForegroundColor Yellow }

    function Update-SessionPath {
        $paths = @(
            [Environment]::GetEnvironmentVariable('Path', 'Machine'),
            [Environment]::GetEnvironmentVariable('Path', 'User')
        ) -join ';'
        $fresh = ($paths -split ';' | Where-Object { $_ -and $_.Trim() }) | Select-Object -Unique
        $env:Path = $fresh -join ';'
    }

    # 1. Ensure execution policy allows current user scripts
    try {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction SilentlyContinue
    } catch { }

    # 2. Dynamic Oh My Posh Theme Setup
    Write-Step 'Oh My Posh theme setup'
    $themesDir = Join-Path $env:LOCALAPPDATA 'Programs\oh-my-posh\themes'
    if (-not (Test-Path -LiteralPath $themesDir)) {
        New-Item -ItemType Directory -Path $themesDir -Force | Out-Null
    }

    $themeChoice = Read-Host "Enter oh-my-posh theme name [default: robbyrussell]"
    if ([string]::IsNullOrWhiteSpace($themeChoice)) {
        $themeChoice = 'robbyrussell'
    }
    $themeName = ($themeChoice.Trim() -replace '\.omp\.json$', '') -replace '\.json$', ''
    $themeFile = Join-Path $themesDir "$themeName.omp.json"
    $themeUrl  = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/$themeName.omp.json"

    Write-Host "   Downloading theme '$themeName'..." -ForegroundColor DarkGray
    try {
        Invoke-RestMethod -Uri $themeUrl -OutFile $themeFile -ErrorAction Stop
        Write-OK "Theme saved to $themeFile"
    } catch {
        Write-Warn "Could not download theme '$themeName' from $themeUrl"
        if ($themeName -ne 'robbyrussell') {
            Write-Host "   Falling back to 'robbyrussell'..." -ForegroundColor Yellow
            $themeName = 'robbyrussell'
            $themeFile = Join-Path $themesDir 'robbyrussell.omp.json'
            $themeUrl  = 'https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/robbyrussell.omp.json'
            try {
                Invoke-RestMethod -Uri $themeUrl -OutFile $themeFile -ErrorAction Stop
                Write-OK "Fallback theme saved to $themeFile"
            } catch {
                Write-Warn "Could not download fallback theme: $($_.Exception.Message)"
            }
        }
    }

    # 3. Applications via winget
    Write-Step 'Command line tools & applications'
    $hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
    if ($hasWinget) {
        $apps = @(
            @{ Name = 'Git';              Id = 'Git.Git';                    Detect = 'git' },
            @{ Name = 'Oh My Posh';       Id = 'JanDeDobbeleer.OhMyPosh';    Detect = 'oh-my-posh' },
            @{ Name = 'fzf';              Id = 'junegunn.fzf';               Detect = 'fzf' },
            @{ Name = 'ripgrep';          Id = 'BurntSushi.ripgrep.MSVC';    Detect = 'rg' },
            @{ Name = 'Neovim';           Id = 'Neovim.Neovim';              Detect = 'nvim' },
            @{ Name = 'PowerShell 7';     Id = 'Microsoft.PowerShell';       Detect = 'pwsh' },
            @{ Name = 'Windows Terminal'; Id = 'Microsoft.WindowsTerminal';  Detect = 'wt' }
        )

        foreach ($app in $apps) {
            if (Get-Command $app.Detect -ErrorAction SilentlyContinue) {
                Write-OK "$($app.Name) is already installed"
                continue
            }
            Write-Host "   Installing $($app.Name)..." -ForegroundColor DarkGray
            & winget install --id $app.Id --exact --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
            Update-SessionPath
            if (Get-Command $app.Detect -ErrorAction SilentlyContinue) {
                Write-OK "$($app.Name) installed"
            } else {
                Write-Warn "$($app.Name) installation did not complete or requires restart"
            }
        }
    } else {
        Write-Warn 'winget is not available - skipping package installations'
    }

    # 4. Fonts
    Write-Step 'Fonts'
    $hasHack = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts' -ErrorAction SilentlyContinue) |
        Get-Member -MemberType NoteProperty | Where-Object { $_.Name -like '*Hack*' }
    if ($hasHack) {
        Write-OK 'Hack Nerd Font is already installed'
    } else {
        if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
            Write-Host '   Installing Hack Nerd Font via oh-my-posh...' -ForegroundColor DarkGray
            & oh-my-posh font install Hack
            Write-OK 'Hack Nerd Font installed'
        } else {
            Write-Warn 'oh-my-posh not found - install Hack Nerd Font manually from nerdfonts.com'
        }
    }

    # 5. PowerShell Modules
    Write-Step 'PowerShell modules'
    $modules = @('posh-git', 'Terminal-Icons', 'PSFzf', 'PSReadLine')
    foreach ($mod in $modules) {
        if (Get-Module -ListAvailable -Name $mod) {
            Write-OK "Module $mod is available"
            continue
        }
        Write-Host "   Installing module $mod..." -ForegroundColor DarkGray
        try {
            Install-Module -Name $mod -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck -ErrorAction Stop
            Write-OK "Module $mod installed"
        } catch {
            Write-Warn "Module $mod failed to install: $($_.Exception.Message)"
        }
    }

    # 6. Windows Terminal Font Configuration
    Write-Step 'Windows Terminal'
    $wtSettingsPaths = @(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
    )
    $wtSettings = $wtSettingsPaths | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($wtSettings) {
        try {
            $json = [IO.File]::ReadAllText($wtSettings) | ConvertFrom-Json
            if (-not $json.profiles) { $json | Add-Member -NotePropertyName profiles -NotePropertyValue (New-Object PSObject) }
            if (-not $json.profiles.defaults) { $json.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue (New-Object PSObject) }
            if (-not $json.profiles.defaults.font) { $json.profiles.defaults | Add-Member -NotePropertyName font -NotePropertyValue (New-Object PSObject) }
            
            if ($json.profiles.defaults.font.face -ne 'Hack Nerd Font') {
                $json.profiles.defaults.font.face = 'Hack Nerd Font'
                [IO.File]::WriteAllText($wtSettings, ($json | ConvertTo-Json -Depth 32), [System.Text.Encoding]::UTF8)
                Write-OK 'Windows Terminal default font set to Hack Nerd Font'
            } else {
                Write-OK 'Windows Terminal is already configured with Hack Nerd Font'
            }
        } catch {
            Write-Warn 'Could not update Windows Terminal settings automatically'
        }
    }

    # 7. PowerShell Profile
    Write-Step 'PowerShell profile'
    function Get-ProfileBlock([string]$Theme) {
        $block = @"
# >>> powershell-setup:managed-block >>>
# Generated by install.ps1 - edits inside this block are overwritten.

# Oh My Posh prompt
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    try {
        if ([Console]::OutputEncoding.WebName -ne 'utf-8') { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 }
        `$poshTheme = Join-Path `$env:LOCALAPPDATA 'Programs\oh-my-posh\themes\$Theme.omp.json'
        if (Test-Path -LiteralPath `$poshTheme) {
            oh-my-posh init pwsh --config `$poshTheme | Invoke-Expression
        } else {
            oh-my-posh init pwsh | Invoke-Expression
        }
    } catch {
        Write-Warning ('oh-my-posh: ' + `$_.Exception.Message)
    }
}

# Git status in prompt and icons
Import-Module posh-git -ErrorAction SilentlyContinue
Import-Module Terminal-Icons -ErrorAction SilentlyContinue

# PSReadLine
try {
    `$psrl = Import-Module PSReadLine -PassThru -ErrorAction Stop
    Set-PSReadLineOption -EditMode Emacs -BellStyle None
    if (`$psrl.Version -ge [version]'2.1.0') {
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

# Aliases & Functions
Remove-Item Alias:ll -Force -ErrorAction SilentlyContinue
function ll {
    `$cleanArgs = @()
    foreach (`$arg in `$args) {
        if (`$arg -match '^-+[la]+$') { continue }
        `$cleanArgs += `$arg
    }
    Get-ChildItem -Force @cleanArgs
}

if (Get-Command git -ErrorAction SilentlyContinue) { Set-Alias -Name g -Value git -Force }
if (Get-Command nvim -ErrorAction SilentlyContinue) { Set-Alias -Name vim -Value nvim -Force }

# Git usr/bin tools (grep, tig, less)
`$gitCmd = Get-Command git -ErrorAction SilentlyContinue
`$gitBin = `$null
if (`$gitCmd) {
    `$gitCandidate = Split-Path -Parent (Split-Path -Parent `$gitCmd.Source)
    if (Test-Path (Join-Path `$gitCandidate 'usr\bin')) { `$gitBin = Join-Path `$gitCandidate 'usr\bin' }
}
if (-not `$gitBin -and (Test-Path 'C:\Program Files\Git\usr\bin')) {
    `$gitBin = 'C:\Program Files\Git\usr\bin'
}

if (`$gitBin) {
    if (Test-Path (Join-Path `$gitBin 'grep.exe')) { Set-Alias -Name grep -Value (Join-Path `$gitBin 'grep.exe') -Force }
    if (Test-Path (Join-Path `$gitBin 'tig.exe')) { Set-Alias -Name tig -Value (Join-Path `$gitBin 'tig.exe') -Force }
    if (Test-Path (Join-Path `$gitBin 'less.exe')) { Set-Alias -Name less -Value (Join-Path `$gitBin 'less.exe') -Force }
} else {
    if (-not (Get-Command grep -ErrorAction SilentlyContinue)) { Set-Alias -Name grep -Value findstr -Force }
}

# Utilities
function which (`$name) {
    `$cmd = Get-Command -Name `$name -ErrorAction SilentlyContinue
    if (-not `$cmd) { return }
    if (`$cmd.CommandType -eq 'Alias') {
        `$resolved = Get-Command -Name `$cmd.Definition -ErrorAction SilentlyContinue
        if (`$resolved -and `$resolved.Source) { return `$resolved.Source }
        return `$cmd.Definition
    }
    if (`$cmd.Source) { return `$cmd.Source }
    if (`$cmd.Path) { return `$cmd.Path }
    return `$cmd.Definition
}
# <<< powershell-setup:managed-block <<<
"@
        return ($block -replace "`r`n|`n", "`r`n")
    }

    function Update-ProfileFile([string]$profilePath, [string]$newBlock) {
        $startMarker = '# >>> powershell-setup:managed-block >>>'
        $endMarker   = '# <<< powershell-setup:managed-block <<<'
        
        $content = ''
        if (Test-Path -LiteralPath $profilePath) {
            $content = [IO.File]::ReadAllText($profilePath)
        }

        $startIndex = $content.IndexOf($startMarker, [StringComparison]::Ordinal)
        $endIndex   = $content.IndexOf($endMarker, [StringComparison]::Ordinal)

        if ($startIndex -ge 0 -and $endIndex -gt $startIndex) {
            $prefix = $content.Substring(0, $startIndex)
            $suffix = $content.Substring($endIndex + $endMarker.Length)
            if ($suffix.StartsWith("`r`n")) { $suffix = $suffix.Substring(2) }
            elseif ($suffix.StartsWith("`n")) { $suffix = $suffix.Substring(1) }
            $finalContent = $prefix + $newBlock + $suffix
        } else {
            $sep = if ($content.Length -gt 0) { "`r`n`r`n" } else { "" }
            $finalContent = $content + $sep + $newBlock
        }

        $dir = Split-Path -Parent $profilePath
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        [IO.File]::WriteAllText($profilePath, $finalContent, [System.Text.Encoding]::UTF8)
        Write-OK "Updated $profilePath"
    }

    $profileBlock = Get-ProfileBlock -Theme $themeName
    $docs = [Environment]::GetFolderPath('MyDocuments')
    $targetProfiles = @(
        (Join-Path (Join-Path $docs 'PowerShell') 'Microsoft.PowerShell_profile.ps1'),
        (Join-Path (Join-Path $docs 'WindowsPowerShell') 'Microsoft.PowerShell_profile.ps1')
    )

    foreach ($p in $targetProfiles) {
        Update-ProfileFile -profilePath $p -newBlock $profileBlock
    }

    Write-Host "`nSetup complete! Restart your terminal or run '. `$PROFILE' to apply." -ForegroundColor Green
}
