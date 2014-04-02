# Terminate script execution if we see an error
$ErrorActionPreference = "Stop"

Import-Module WebAdministration

# Import all modules
function Import-AllModules() {
    $gitModulePath = $PSScriptRoot + "\modules\"
    Get-ChildItem $gitModulePath | Select -ExpandProperty FullName | Import-Module -DisableNameChecking -Force
}

Import-AllModules | Out-Null

List-Services | ConvertTo-Json