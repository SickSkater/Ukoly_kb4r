param(
    [Parameter(Mandatory = $true, Position = 0)]
    [AllowEmptyString()]
    [string] $Text
)

# Sjednoti velikost pismen, odstrani diakritiku, mezery a interpunkci.
$bezDiakritiky = $Text.Normalize([Text.NormalizationForm]::FormD) -replace '\p{Mn}', ''
$normalizovany = ($bezDiakritiky.ToLowerInvariant() -replace '[^\p{L}\p{Nd}]', '')
$obraceny = if ($normalizovany.Length -eq 0) {
    # Vyraz s nulovou delkou povazujeme za palindrom.
    ''
} else {
    -join ([char[]] $normalizovany)[($normalizovany.Length - 1)..0]
}

[pscustomobject]@{
    Text               = $Text
    NormalizovanyText  = $normalizovany
    JePalindrom        = ($normalizovany -ceq $obraceny)
}
