param(
    [string] $OutputDirectory = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$expected = @(
    [pscustomobject]@{ Name = 'np'; Definition = 'notepad.exe' }
    [pscustomobject]@{ Name = 'ct'; Definition = 'control.exe' }
)
$jsonPath = Join-Path $OutputDirectory 'aliases.json'
$xmlPath = Join-Path $OutputDirectory 'aliases.xml'

function Assert-AliasState {
    param([bool] $ShouldExist, [string] $Phase)

    foreach ($item in $expected) {
        $actual = Get-Alias -Name $item.Name -ErrorAction SilentlyContinue
        if ($ShouldExist) {
            if ($null -eq $actual -or $actual.Definition -ne $item.Definition) {
                throw "Chybný alias $($item.Name) po fázi '$Phase'."
            }
        }
        elseif ($null -ne $actual) {
            throw "Alias $($item.Name) zůstal po fázi '$Phase'."
        }
    }
    Write-Output "OK: $Phase"
}

function Remove-DemoAliases {
    foreach ($item in $expected) {
        Remove-Item -LiteralPath "Alias:$($item.Name)" -ErrorAction Stop
    }
}

# Skript běží přes pwsh -NoProfile -File, takže aliasy existují pouze v tomto procesu.
foreach ($item in $expected) {
    Set-Alias -Name $item.Name -Value $item.Definition -Force
}
Assert-AliasState -ShouldExist $true -Phase 'vytvoření'

$snapshot = @(
    foreach ($item in $expected) {
        Get-Alias -Name $item.Name | Select-Object Name, Definition
    }
)
$snapshot | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $jsonPath -Encoding utf8
$snapshot | Export-Clixml -LiteralPath $xmlPath
Write-Output "Záloha JSON: $jsonPath"
Write-Output "Záloha XML:  $xmlPath"

Remove-DemoAliases
Assert-AliasState -ShouldExist $false -Phase 'smazání před JSON'
$jsonSnapshot = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
foreach ($item in $jsonSnapshot) {
    Set-Alias -Name $item.Name -Value $item.Definition
}
Assert-AliasState -ShouldExist $true -Phase 'obnovení z JSON'

Remove-DemoAliases
Assert-AliasState -ShouldExist $false -Phase 'smazání před XML'
foreach ($item in @(Import-Clixml -LiteralPath $xmlPath)) {
    Set-Alias -Name $item.Name -Value $item.Definition
}
Assert-AliasState -ShouldExist $true -Phase 'obnovení z XML'

Get-Alias -Name np, ct | Select-Object Name, Definition | Format-Table -AutoSize | Out-String | Write-Output
