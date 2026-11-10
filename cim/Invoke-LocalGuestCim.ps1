# Run directly inside the Windows VirtualBox guest, never on the Windows host.
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $ExpectedGuestComputerName,

    [string] $FaxLocation = 'Učebna 101'
)

$ErrorActionPreference = 'Stop'

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Pro zápis přes CIM spusťte PowerShell ve VM jako správce.'
    }
}

# Both checks must pass before the script can even read a change target.
$computer = Get-CimInstance -ClassName Win32_ComputerSystem
if ($computer.Name -ine $ExpectedGuestComputerName) {
    throw "Tento počítač je '$($computer.Name)', očekáván byl '$ExpectedGuestComputerName'."
}
if ($computer.Model -notmatch 'VirtualBox' -and $computer.Manufacturer -notmatch 'innotek|Oracle') {
    throw "Počítač '$($computer.Name)' nevypadá jako VirtualBox VM (výrobce '$($computer.Manufacturer)', model '$($computer.Model)')."
}

Write-Output "Cíl: $($computer.Name) ($($computer.Manufacturer), $($computer.Model))"

$printerClass = Get-CimClass -ClassName Win32_Printer
Write-Output "Win32_Printer: $($printerClass.CimClassProperties.Count) vlastností, $($printerClass.CimClassMethods.Count) metod"
$printerClass.CimClassProperties |
    Select-Object Name, CimType, Flags |
    Format-Table -AutoSize |
    Out-String |
    Write-Output

Write-Output 'Tiskové fronty před změnou:'
$printers = @(Get-CimInstance -ClassName Win32_Printer)
$printers |
    Select-Object Name, Location, DriverName, PortName |
    Format-Table -AutoSize |
    Out-String |
    Write-Output

$fax = $printers | Where-Object { $_.Name -eq 'Fax' } | Select-Object -First 1
$volume = Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter='C:'"
if ($null -eq $volume) {
    throw 'Ve VM nebyl nalezen svazek C:; žádnou změnu nelze bezpečně provést.'
}
Write-Output "C: před změnou: Label='$($volume.Label)', FileSystem='$($volume.FileSystem)'"

Write-Output 'Účty bez evidovaného LastLogon podle Get-LocalUser (neprůkazné pro nikdy nepoužité):'
$localUsers = @(Get-LocalUser)
$localUsers |
    Where-Object { $null -eq $_.LastLogon } |
    Select-Object Name, Enabled, LastLogon |
    Format-Table -AutoSize |
    Out-String |
    Write-Output

Write-Output 'Uzamčené místní účty podle Win32_UserAccount:'
$cimUsers = @(Get-CimInstance -ClassName Win32_UserAccount -Filter 'LocalAccount=True')
$cimUsers |
    Where-Object { $_.Lockout } |
    Select-Object Domain, Name, Disabled, Lockout |
    Format-Table -AutoSize |
    Out-String |
    Write-Output

Write-Output 'Profily bez evidovaného přihlášení podle Win32_NetworkLoginProfile (neprůkazné):'
Get-CimInstance -ClassName Win32_NetworkLoginProfile |
    Where-Object { $null -eq $_.LastLogon -and $_.NumberOfLogons -eq 0 } |
    Select-Object Name, LastLogon, NumberOfLogons |
    Format-Table -AutoSize |
    Out-String |
    Write-Output

if ($null -eq $fax) {
    Write-Warning 'Fronta Fax ve VM chybí. Její Location se neměnila; žádná náhradní fronta nebyla vytvořena.'
    $faxStatus = 'Chybí'
}
elseif ($fax.Location -eq $FaxLocation) {
    Write-Output "Fax.Location už je '$FaxLocation'."
    $faxStatus = 'Již nastaveno'
}
elseif ($PSCmdlet.ShouldProcess("$($computer.Name): Fax", "Location = '$FaxLocation'")) {
    Assert-Administrator
    Set-CimInstance -InputObject $fax -Property @{ Location = $FaxLocation } -Confirm:$false
    $faxAfter = Get-CimInstance -ClassName Win32_Printer -Filter "Name='Fax'"
    if ($null -eq $faxAfter -or $faxAfter.Location -ne $FaxLocation) {
        throw 'Ověření Fax.Location po zápisu selhalo.'
    }
    Write-Output "Fax.Location po změně: '$($faxAfter.Location)'"
    $faxStatus = 'Změněno a ověřeno'
}
else {
    $faxStatus = 'Nezměněno (WhatIf/odmítnuto)'
}

if ($volume.Label -eq 'System') {
    Write-Output 'C:.Label už je System.'
    $volumeStatus = 'Již nastaveno'
}
elseif ($PSCmdlet.ShouldProcess("$($computer.Name): C:", "Label = 'System'")) {
    Assert-Administrator
    Set-CimInstance -InputObject $volume -Property @{ Label = 'System' } -Confirm:$false
    $volumeAfter = Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter='C:'"
    if ($null -eq $volumeAfter -or $volumeAfter.Label -ne 'System') {
        throw 'Ověření C:.Label po zápisu selhalo.'
    }
    Write-Output "C: po změně: Label='$($volumeAfter.Label)'"
    $volumeStatus = 'Změněno a ověřeno'
}
else {
    $volumeStatus = 'Nezměněno (WhatIf/odmítnuto)'
}

[pscustomobject]@{
    ComputerName = $computer.Name
    FaxStatus = $faxStatus
    FaxLocation = if ($null -eq $fax) { $null } else { (Get-CimInstance -ClassName Win32_Printer -Filter "Name='Fax'").Location }
    DiskCStatus = $volumeStatus
    DiskCLabel = (Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter='C:'").Label
}
