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

`irm` (Invoke-RestMethod) downloads the script and `iex` (Invoke-Expression) runs it.

What the command does:

1. **Theme Selection**: Prompts for your desired Oh My Posh theme (defaults to `robbyrussell`) and downloads the theme file to `$env:LOCALAPPDATA\Programs\oh-my-posh\themes\<theme>.omp.json`.
2. **Tools & Applications**: Installs Git, Oh My Posh, fzf, ripgrep, Neovim, PowerShell 7, and Windows Terminal via `winget` (skipping any that are already installed).
3. **Nerd Font**: Installs Hack Nerd Font (via `oh-my-posh font install Hack`) if not already present.
4. **PowerShell Modules**: Installs `posh-git`, `Terminal-Icons`, `PSFzf`, and `PSReadLine`.
5. **Windows Terminal Font**: Sets the default font face to `Hack Nerd Font` in Windows Terminal settings.
6. **PowerShell Profile**: Configures your `$PROFILE` with prompt initialization, icons, git status, history prediction, and reliable aliases/utilities (`ll`, `g`, `vim`, `grep`, `tig`, `less`, `which`).

| Step | Component | Tool / Source |
| --- | --- | --- |
| 1 | Oh My Posh theme (`.omp.json`) | GitHub / JanDeDobbeleer |
| 2 | Git, Oh My Posh, fzf, ripgrep, Neovim, pwsh, wt | `winget` |
| 3 | Hack Nerd Font | `oh-my-posh font install` |
| 4 | posh-git, Terminal-Icons, PSFzf, PSReadLine | PowerShell Gallery |
| 5 | `$PROFILE` configuration | Managed block in `$PROFILE` |
| 6 | Windows Terminal default font | Terminal `settings.json` |

Notes:

* Every step is idempotent — it checks what is already installed and skips it.
* Your `$PROFILE` is safely managed inside marked blocks (`# >>> powershell-setup:managed-block >>>`), preserving any custom commands you add outside.

## Manual Installation

Prefer to do it step by step?

### 1. Applications

```powershell
winget install Git.Git --source winget
winget install JanDeDobbeleer.OhMyPosh --source winget
winget install junegunn.fzf --source winget
winget install BurntSushi.ripgrep.MSVC --source winget
winget install Neovim.Neovim --source winget
```

### 2. Nerd Font (Hack)

```powershell
oh-my-posh font install Hack
```

Then in Windows Terminal `settings.json`:
```json
"profiles": { "defaults": { "font": { "face": "Hack Nerd Font" } } }
```

### 3. PowerShell Modules

```powershell
Install-Module posh-git, Terminal-Icons, PSFzf, PSReadLine -Scope CurrentUser -Force -AllowClobber
```

### 4. Oh My Posh Theme

Create the themes folder and download your theme (e.g., `robbyrussell`):

```powershell
$themesDir = Join-Path $env:LOCALAPPDATA 'Programs\oh-my-posh\themes'
New-Item -ItemType Directory -Path $themesDir -Force
Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/robbyrussell.omp.json' -OutFile (Join-Path $themesDir 'robbyrussell.omp.json')
```

### 5. Profile Configuration

Add the managed block to your `$PROFILE` (`code $PROFILE` or `notepad $PROFILE`).

### 6. Reload

```powershell
. $PROFILE
```
