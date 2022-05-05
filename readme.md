# This is my Windows Terminal (PowerShell) Setup

<img src="https://github.com/nishu-murmu/powershell-setup/blob/main/images/terminal_two.png" width="100%">

### This is the one currently using

<img src="https://github.com/nishu-murmu/powershell-setup/blob/main/images/terminal_three.png">

#### Most of my work and navigation through my PC happens in terminal so I need to set it up to look clean and nicer for my workflow.

#### Setting it up with all the colors and glyphs, fonts and more.

## Installation Guide

### To add icons in your terminal
1. First of all you need to install a [Nerd Fonts](https://www.nerdfonts.com/font-downloads) (Hack Nerd Fonts preferable).
2. Change your Terminal Fonts to specific Nerd Font you just install.
3. Install [terminal-icons](powershellgallery.com/packages/Terminal-Icons/0.9.0) from powershell gallery.
4. Add this line in your $PROFILE file `Import-Module -Name Terminal-Icons`.
5. Now paste `. $PROFILE` in your terminal and enter to see the effect.

### To update your terminal
1. After downloading a package install a custom prompt engine for powershell using winget [oh-my-posh](https://ohmyposh.dev/docs/installation/windows).
    ```
    winget install oh-my-posh
    ```
2. Now add any one of the theme in oh-my-posh folder by adding this line in your $PROFILE file.
    ```
    oh-my-posh --init --shell pwsh --config ~/jandedobbeleer.omp.json | Invoke-Expression
    ```
3. Now run the `$PROFILE` in command prompt.

### To change default themes
1. Enter this is powershell terminal
```
New-Item -Path "$home\Documents\WindowsPowerShell\Modules\oh-my-posh" -Name "themes" -ItemType Directory; Set-Location -Path "$home\Documents\WindowsPowerShell\Modules\oh-my-posh\themes"; Invoke-WebRequest -UseBasicParsing -Uri https://api.github.com/repos/JanDeDobbeleer/oh-my-posh/contents/themes | Select-Object -ExpandProperty Content | ConvertFrom-Json | ForEach-Object {$_ | Select-Object -ExpandProperty name | Select-String -Pattern ".*.omp.json"} | ForEach-Object {$_.toString().Replace(".omp.json", "")} | ForEach-Object {Invoke-WebRequest -Uri "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/$_.omp.json" -UseBasicParsing -OutFile "$_.omp.json"}
```
2. Go to location `C:\Users\<User>\Documents\WindowsPowerShell\Modules\oh-my-posh` and copy the theme you want to use and paste in the `$PROFILE` file.
