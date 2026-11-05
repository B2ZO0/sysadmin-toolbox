function New-RandomPassword {
    <#
    .SYNOPSIS
        Generates strong random passwords or passphrases with a cryptographic random generator.
    .DESCRIPTION
        Passwords mix lower case, upper case, digits and symbols, with at least one of each and
        without look-alike characters (0/O, 1/l/I). Passphrases join random words, easier to type.
    .EXAMPLE
        New-RandomPassword -Length 20 -Count 5
    .EXAMPLE
        New-RandomPassword -Passphrase -Words 5
    .EXAMPLE
        New-RandomPassword -AsSecureString | Set-ADAccountPassword -Identity jdoe -Reset
    #>
    [CmdletBinding(DefaultParameterSetName = 'Password')]
    [OutputType([string], [securestring])]
    param(
        [Parameter(ParameterSetName = 'Password')][ValidateRange(8, 256)][int]$Length = 16,
        [Parameter(ParameterSetName = 'Password')][switch]$NoSymbols,
        [Parameter(ParameterSetName = 'Passphrase')][switch]$Passphrase,
        [Parameter(ParameterSetName = 'Passphrase')][ValidateRange(3, 12)][int]$Words = 4,
        [ValidateRange(1, 1000)][int]$Count = 1,
        [switch]$AsSecureString
    )
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    function Get-RandomIndex([int]$Max) {
        # rejection sampling: no modulo bias
        $bytes = New-Object byte[] 4
        $limit = [uint32]::MaxValue - ([uint32]::MaxValue % [uint32]$Max)
        do { $rng.GetBytes($bytes); $v = [BitConverter]::ToUInt32($bytes, 0) } while ($v -ge $limit)
        [int]($v % [uint32]$Max)
    }
    $lower = 'abcdefghijkmnopqrstuvwxyz'; $upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ'; $digits = '23456789'; $symbols = '!#$%&*+-=?@_'
    $wordList = 'amber anchor apple arrow aspen atlas basil beacon birch bison blaze bloom breeze brook cable cactus canyon cedar cherry cipher citrus clover cobalt comet copper coral cosmic crane crystal dawn delta desert dune eagle ember falcon fern fjord flint forest frost galaxy garnet glacier granite harbor hazel horizon indigo iris island ivory jade jasper juniper kayak kernel lagoon lantern laser lemon lotus lunar magnet mango maple marble meadow meteor mint monsoon mosaic nebula nectar nickel oasis ocean olive onyx orbit orchid otter panda pebble pepper photon pilot pixel planet plaza polar prism pulsar quartz radar raven reef ripple rocket ruby saffron sage sapphire satellite shadow sierra signal silver sonar spark sphinx spruce summit sunset tango thunder tiger timber topaz tulip tundra turbo velvet violet vortex walnut willow zenith zephyr' -split ' '
    for ($n = 0; $n -lt $Count; $n++) {
        if ($Passphrase) {
            $parts = for ($i = 0; $i -lt $Words; $i++) { $w = $wordList[(Get-RandomIndex $wordList.Count)]; $w.Substring(0, 1).ToUpper() + $w.Substring(1) }
            $result = ($parts -join '-') + '-' + (Get-RandomIndex 100)
        } else {
            $sets = @($lower, $upper, $digits); if (-not $NoSymbols) { $sets += $symbols }
            $all = -join $sets
            $chars = New-Object System.Collections.Generic.List[char]
            foreach ($s in $sets) { $chars.Add($s[(Get-RandomIndex $s.Length)]) }
            while ($chars.Count -lt $Length) { $chars.Add($all[(Get-RandomIndex $all.Length)]) }
            for ($i = $chars.Count - 1; $i -gt 0; $i--) { $j = Get-RandomIndex ($i + 1); $tmp = $chars[$i]; $chars[$i] = $chars[$j]; $chars[$j] = $tmp }
            $result = -join $chars
        }
        if ($AsSecureString) {
            $sec = New-Object System.Security.SecureString
            foreach ($ch in $result.ToCharArray()) { $sec.AppendChar($ch) }
            $sec.MakeReadOnly(); $sec
        } else { $result }
    }
    $rng.Dispose()
}
