# This is my Windows Terminal (PowerShell) Setup

<img src="https://github.com/nishu-murmu/powershell-setup/blob/main/images/terminal_two.png" width="100%">

### This is the one currently using

<img src="https://github.com/nishu-murmu/powershell-setup/blob/main/images/terminal_three.png">

#### Most of my work and navigation through my PC happens in terminal so I need to set it up to look clean and nicer for my workflow.

#### Setting it up with all the colors and glyphs, fonts and more.

## Installation (one command)

Open a PowerShell terminal and run:

```powershell
irm https://raw.githubusercontent.com/nishu-murmu/powershell-setup/main/install.ps1 | iex
```

`irm` (Invoke-RestMethod) downloads the script from the official source of this
repository and `iex` (Invoke-Expression) runs it. That is the same download-and-run
pattern used by scoop and oh-my-posh themselves.

What the command does, in order:

| Step | What gets installed | Tool |
| --- | --- | --- |
| 1 | winget (App Installer), bootstrapped from Microsoft when missing | aka.ms/getwinget |
| 2 | scoop | get.scoop.sh |
| 3 | Git, fzf, ripgrep | winget + scoop |
| 4 | Oh My Posh, PowerShell 7, Neovim, Windows Terminal | winget |
| 5 | Hack Nerd Font (all weights, installed for your user) | nerd-fonts release |
| 6 | posh-git, Terminal-Icons, PSFzf, PSReadLine | PowerShell Gallery |
| 7 | `$PROFILE` for **both** Windows PowerShell 5.1 and PowerShell 7 | generated block |
| 8 | Windows Terminal default font | only set if you never chose one |

Notes:

* Every step is idempotent - it only installs what is missing, so you can re-run the
  command any time to repair the setup.
* No administrator rights are required. winget may still show a UAC prompt for
  machine-wide packages such as Git.
* Packages that are already installed are detected and skipped.
* Your `$PROFILE` is backed up (`.bak-<timestamp>`) before it is changed, and only
  the managed block between the markers is touched - everything you wrote outside of
  it stays exactly as it was.

### Development branch

The development branch may contain experimental changes and should only be used for
testing on non-production systems:

```powershell
irm https://raw.githubusercontent.com/nishu-murmu/powershell-setup/dev/install.ps1 | iex
```

## Manual installation

Prefer to know what happens? Do it step by step.

### 1. Package managers

```powershell
# winget comes with Windows (App Installer). If it is missing:
Invoke-WebRequest -Uri https://aka.ms/getwinget -OutFile getwinget.msixbundle
Add-AppxPackage .\getwinget.msixbundle

# scoop
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
irm https://get.scoop.sh | iex
```

### 2. Tools

```powershell
winget install Git.Git --source winget
winget install JanDeDobbeleer.OhMyPosh --source winget
scoop install fzf ripgrep
```

### 3. Nerd Font (Hack)

Install a [Nerd Font](https://www.nerdfonts.com/font-downloads) so the prompt icons
render - Hack Nerd Font is the one used here. The script installs it per user, or
you can run `oh-my-posh font install Hack` after installing Oh My Posh.

Then set the terminal font (the script does this for you when no font is set):

```json
"profiles": { "defaults": { "font": { "face": "Hack Nerd Font" } } }
```

### 4. PowerShell modules

```powershell
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module posh-git, Terminal-Icons, PSFzf -Scope CurrentUser -Force -AllowClobber
```

### 5. Prompt engine

Pick a theme, they are all listed by:

```powershell
Get-PoshThemes
```

Then point the managed block in your `$PROFILE` at it (default here is `robbyrussell`):

```powershell
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\robbyrussell.omp.json" | Invoke-Expression
```

The block lives between these markers in `$PROFILE`, so re-running `install.ps1`
updates it without touching anything else you have added:

```powershell
# >>> powershell-setup:managed-block >>>
# <<< powershell-setup:managed-block <<<
```

`user_profile.ps1` in this repository is the reference copy of that block.

### 6. Reload

```powershell
. $PROFILE
```
