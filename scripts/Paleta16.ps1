# Zobrazi sestnact prednastavenych barev aktualniho terminalu.
# Barvy ConsoleColor 0-15 odpovidaji standardni palete konzole Windows.
$barvy = [Enum]::GetValues([ConsoleColor])

foreach ($barva in $barvy) {
    $cislo = [int]$barva
    $popredi = if ($cislo -in @(7, 8, 10, 11, 14, 15)) {
        [ConsoleColor]::Black
    } else {
        [ConsoleColor]::White
    }

    Write-Host (' {0,2} {1,-12} ' -f $cislo, $barva) -BackgroundColor $barva -ForegroundColor $popredi
}
