# This is my Windows Terminal (PowerShell) Setup

<img src="https://github.com/nishu-murmu/powershell-setup/blob/main/images/terminal_two.png" width="100%">

#### Most of my work and navigation through my PC happens in terminal so I need to set it up to look clean and nicer for my workflow.
#### Setting it up with all the colors and glyphs, fonts and more.

## Installation Guide

### To add icons in your terminal
1. First of all you need to install a [Nerd Fonts](https://www.nerdfonts.com/font-downloads) (Hack Nerd Fonts preferable).
2. Change your Terminal Fonts to specific Nerd Font you just install.
3. Add this line in your $PROFILE file `Import-Module -Name Terminal-Icons`.
4. Now paste `. $PROFILE` in your terminal and enter to see the effect.

### To update your terminal
1. Download any one package from the three [Scoop](https://scoop.sh/), [Chocolatey](https://chocolatey.org/install#generic), [winget](https://docs.microsoft.com/en-us/windows/package-manager/winget/).
2. After downloading a package install a custom prompt engine for powershell [oh-my-posh](https://ohmyposh.dev/docs/windows).
3. Now you're ready to change your terminal by adding this line in your $PROFILE file`Import-Module oh-my-posh`
4. Now add any one of the theme in oh-my-posh folder by adding this line in your $PROFILE file `oh-my-posh --init --shell pwsh --config ~/jandedobbeleer.omp.json | Invoke-Expression`.
5. Now paste `. $PROFILE` in your terminal and enter to see the effect.
