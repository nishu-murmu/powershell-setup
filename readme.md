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
   winget install JanDeDobbeleer.OhMyPosh -s winget
    ```
2. Then add this inside the terminal
    ```
    Get-PoshThemes
    ```
3. Then add this lines inside the `$PROFILE` file.
    ```
    oh-my-posh init pwsh --config C:\Users\username\AppData\Local\Programs\oh-my-posh\themes/jandedobbeleer.omp.json | Invoke-Expression
    ```
4. To change the themes you can change the **themeName** inside  `C:\Users\_username_\AppData\Local\Programs\oh-my-posh\themes/themeName.omp.json` lines in `$PROFILE` file.
