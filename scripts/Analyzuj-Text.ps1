param(
    [Parameter(Mandatory = $true, Position = 0)]
    [AllowEmptyString()]
    [string] $Text
)

# Za mezery se pro tento ucel povazuje jakakoli bila znacka (i tabulator).
$bezMezer = $Text -replace '\s', ''
$pocetSlov = if ([string]::IsNullOrWhiteSpace($Text)) {
    0
} else {
    @($Text.Trim() -split '\s+').Count
}

# Ceske samohlasky vcetne dlouhych variant; porovnani nerozlisuje velikost.
$pocetSamohlasek = [regex]::Matches(
    $Text,
    '[aáeéěiíoóuúůyý]',
    [Text.RegularExpressions.RegexOptions]::IgnoreCase
).Count

[pscustomobject]@{
    ZnakuSMezerami = $Text.Length
    ZnakuBezMezer  = $bezMezer.Length
    Samohlasek     = $pocetSamohlasek
    Slov           = $pocetSlov
}
