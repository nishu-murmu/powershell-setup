Import-Module oh-my-posh 
oh-my-posh --init --shell pwsh --config ~/night-owl.omp.json | Invoke-Expression 

Import-Module -Name Terminal-Icons 
Get-ChildItem | Format-Wide
