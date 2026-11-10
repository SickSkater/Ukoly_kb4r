# Run only inside the Windows 11 VirtualBox guest as an administrator.
# The fax queue is created only if the real Microsoft fax driver and port exist.
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [string] $ExpectedGuestComputerName = 'win11',
    [string] $FaxLocation = 'Učebna 101'
)

$ErrorActionPreference = 'Stop'
$capabilityName = 'Print.Fax.Scan~~~~0.0.1.0'

function Stop-Incomplete {
    param([int] $Code, [string] $Reason)
    Write-Warning $Reason
    Write-Output "FaxStatus = INCOMPLETE ($Code)"
    exit $Code
}

$computer = Get-CimInstance -ClassName Win32_ComputerSystem
if ($computer.Name -ine $ExpectedGuestComputerName) {
    throw "Cílem je '$($computer.Name)', očekávaná VM je '$ExpectedGuestComputerName'."
}
if ($computer.Model -notmatch 'VirtualBox' -or $computer.Manufacturer -notmatch 'innotek|Oracle') {
    throw "'$($computer.Name)' není rozpoznaná jako VirtualBox VM."
}
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Spusťte soubor Run-GuestFax.cmd ve VM jako správce.'
}
Write-Output "Cíl: $($computer.Name) ($($computer.Manufacturer), $($computer.Model))"

$fax = Get-CimInstance -ClassName Win32_Printer -Filter "Name='Fax'"
if ($null -eq $fax) {
    $capability = Get-WindowsCapability -Online -Name $capabilityName | Select-Object -First 1
    if ($null -eq $capability) {
        Stop-Incomplete -Code 11 -Reason "Funkce $capabilityName nebyla v této instalaci Windows nalezena."
    }
    Write-Output "Windows Fax and Scan před změnou: $($capability.State)"

    if ($capability.State -ne 'Installed') {
        if (-not $PSCmdlet.ShouldProcess($computer.Name, "Nainstalovat Windows capability $capabilityName")) {
            Stop-Incomplete -Code 20 -Reason 'Instalace Windows Fax and Scan nebyla provedena.'
        }
        $installation = Add-WindowsCapability -Online -Name $capabilityName -ErrorAction Stop
        $capability = Get-WindowsCapability -Online -Name $capabilityName | Select-Object -First 1
        Write-Output "Windows Fax and Scan po instalaci: $($capability.State)"
        if ($capability.State -ne 'Installed') {
            Stop-Incomplete -Code 11 -Reason 'Instalace funkce se nedokončila do stavu Installed.'
        }
        if ([string]$installation.RestartNeeded -match '^(Yes|True)$') {
            Stop-Incomplete -Code 10 -Reason 'Windows požadují restart VM. Restartujte ji a spusťte tento soubor znovu.'
        }
    }

    $fax = Get-CimInstance -ClassName Win32_Printer -Filter "Name='Fax'"
    if ($null -eq $fax) {
        $driver = Get-PrinterDriver -Name 'Microsoft Shared Fax Driver' -ErrorAction SilentlyContinue
        $port = Get-PrinterPort -Name 'SHRFAX:' -ErrorAction SilentlyContinue
        Write-Output "Skutečný faxový ovladač: $($driver.Name)"
        Write-Output "Skutečný faxový port: $($port.Name)"
        if ($null -eq $driver -or $null -eq $port) {
            Stop-Incomplete -Code 11 -Reason 'Po instalaci Windows Fax and Scan chybí Microsoft Shared Fax Driver nebo SHRFAX:; náhradní tiskárnu nevytvářím.'
        }
        if (-not $PSCmdlet.ShouldProcess($computer.Name, 'Vytvořit frontu Fax se skutečným faxovým ovladačem a portem')) {
            Stop-Incomplete -Code 20 -Reason 'Fronta Fax nebyla vytvořena.'
        }
        Add-Printer -Name 'Fax' -DriverName $driver.Name -PortName $port.Name -Confirm:$false -ErrorAction Stop
        # The print spooler can take a moment to publish a newly created queue to CIM.
        for ($attempt = 1; $attempt -le 10; $attempt++) {
            $fax = Get-CimInstance -ClassName Win32_Printer -Filter "Name='Fax'"
            if ($null -ne $fax) { break }
            Start-Sleep -Seconds 1
        }
        if ($null -eq $fax) {
            Stop-Incomplete -Code 11 -Reason 'Po Add-Printer nebyla fronta Fax přes CIM nalezena.'
        }
        Write-Output "Vytvořena fronta Fax: DriverName='$($fax.DriverName)', PortName='$($fax.PortName)'"
    }
}

if ($fax.DriverName -notmatch 'Fax') {
    Stop-Incomplete -Code 12 -Reason "Fronta Fax používá ovladač '$($fax.DriverName)', který nevypadá jako faxový; umístění neměním."
}
Write-Output "Fax před změnou: DriverName='$($fax.DriverName)', PortName='$($fax.PortName)', Location='$($fax.Location)'"

if ($fax.Location -ne $FaxLocation) {
    if (-not $PSCmdlet.ShouldProcess($computer.Name, "Nastavit Fax.Location na '$FaxLocation' přes CIM")) {
        Stop-Incomplete -Code 20 -Reason 'Umístění fronty Fax nebylo změněno.'
    }
    Set-CimInstance -InputObject $fax -Property @{ Location = $FaxLocation } -Confirm:$false -ErrorAction Stop
}

$verified = Get-CimInstance -ClassName Win32_Printer -Filter "Name='Fax'"
if ($null -eq $verified -or $verified.Location -ne $FaxLocation) {
    throw 'Ověření Fax.Location po zápisu přes CIM selhalo.'
}
Write-Output "Fax po změně: DriverName='$($verified.DriverName)', PortName='$($verified.PortName)', Location='$($verified.Location)'"
[pscustomobject]@{
    ComputerName = $computer.Name
    FaxStatus = 'Nastaveno a ověřeno'
    FaxDriver = $verified.DriverName
    FaxPort = $verified.PortName
    FaxLocation = $verified.Location
}
exit 0
