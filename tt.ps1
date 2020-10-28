$script:Components = @{
    PS = "PS"
    Date = { Get-Date -Format "HH:mm" }
    Venv = { if ($env:VIRTUAL_ENV) { Split-Path -Leaf $env:VIRTUAL_ENV } }
    LastTime = {
        $dur = (Get-History -ErrorAction SilentlyContinue -Count 1).Duration
        if ($dur) {
            $fmt = 'mm\:ss\.fff'
            if ($dur.Hours -gt 0) { $fmt = 'hh\:' + $fmt }
            $dur.ToString($fmt)
        }
    }
    PWD = { (Get-Location).ProviderPath }
    Nesting = { param($ch) $ch * $NestedPromptLevel }
    DirStack = { param($ch) $ch * (Get-Location -Stack).Count }
}

function Add-ScriptComponent ([String]$Name, [ScriptBlock]$Script) {
    $script:Components[$Name] = $Script
}

function Remove-ScriptComponent ([String]$Name) {
    $script:Components.Remove($Name)
}

function Get-PromptLayout ($ScriptBlock) {
    $sep = [PSCustomObject]@{String=""; Powerline=$false}
    function Separator($String, [Switch]$Powerline) {
        $sep.String=$String
        $sep.Powerline=$Powerline
    }
    function Section {
        [CmdletBinding()]
        param($Item, $Foreground, $Background, $Delims, $Text)
        if ($Item) {
            $script = $script:Components.$Item
            if ($script -is [String]) {
                $Text = $script
                $script = $null
            }
        }
        [PSCustomObject]@{
            Script=$script
            Foreground=$Foreground
            Background=$Background
            Delims=$Delims
            Text=$Text
        }
    }
    & $ScriptBlock
    Write-Host -Fore Blue "SEP: $sep"
}

$p = PromptLayout {
    Separator [char]0xE0B0 -Powerline
    Section PS -F Cyan -B Red
    Section Date Bisque -B AliceBlue
    Section Git Green
    Section LastTime Blue -Delims "{}"
    Section PWD Yellow
    Section DirStack -Text ">"
    Section -Text ">"
}

$ansi_codes = @{
    DarkGray=60
    Red=61
    Green=62
    Yellow=63
    Blue=64
    Magenta=65
    Cyan=66
    White=67
    Black=0
    DarkRed=1
    DarkGreen=2
    DarkYellow=3
    DarkBlue=4
    DarkMagenta=5
    DarkCyan=6
    Gray=7
}

function ANSIcolour ($Colour, $Offset) {
    $orig = $Colour
    if ($null -eq $Colour) {
        return
    }
    if ($Colour -is [String]) {
        try {
            $Colour = [ConsoleColor]$Colour
        } catch {
            $dc = [Drawing.Color]::FromName($Colour)
            if ($dc.IsKnownColor) {
                $Colour = $dc
            } else {
                throw "Unknown colour: $orig"
            }
        }
    }
    if ($Colour -is [ConsoleColor]) {
        $Offset + $ansi_codes[[String]$Colour]
    }
    elseif ($Colour -is [Drawing.Color]) {
        ($Offset+8), 2, $Colour.R, $Colour.G, $Colour.B
    }
    elseif ($Colour -is [Object[]]) {
        ($Offset+8), 2
        $Colour
    }
    else {
        throw "Unknown colour: $orig"
    }
}

function ANSI {
    param (
        $Foreground,
        $Background,
        [Switch]$Bold,
        [Switch]$Dim,
        [Switch]$Underline,
        [Switch]$Reverse
    ) 
    if ($Bold) { 1 }
    if ($Dim) { 2 }
    if ($Underline) { 4 }
    if ($Reverse) { 7 }
    ANSIcolour $Foreground 30
    ANSIcolour $Background 40
}

function ANSIstr {
    param (
        $Text,
        $Foreground,
        $Background,
        [Switch]$Bold,
        [Switch]$Dim,
        [Switch]$Underline,
        [Switch]$Reverse,
        [Switch]$NoReset
    )
    $reset = if ($NoReset) { "" } else { "`e[0m" }
    $ops = (ANSI $Foreground $Background -Bold:$Bold -Dim:$Dim -Underline:$Underline -Reverse:$Reverse) -join ";"
    "`e[${ops}m${Text}${reset}"
}

$A=@{Text="Hello"; Foreground="Black"; Background=(162,171,98); Underline=$true}
ANSI @A
Write-Host ("XXXX" + (ANSIstr @A))

function get_colour($fg, $bg) {

    # Black Red Green Yellow Blue Magenta Cyan White
    # Dark FG = 30
    # (Light) FG = 90
    # Dark BG = 40
    # (Light) FG = 100
    #
    # 0 = reset
    # 1 = bold, 2 = dim, 4 = underline, 7 = reverse
    # 38 = FG extended
    # 39 = FG default
    # 48 = BG extended
    # 49 = BG default
    #
    # Extended: 2;r;g;b and 5;index


    $colours = @{}
    if ($null -ne $fg) { $colours["Foreground"] = $fg }
    if ($null -ne $bg) { $colours["Background"] = $bg }
    $enable = ""
    if ($host.UI.SupportsVirtualTerminal) {
        foreach ($item in $colours.GetEnumerator()) {
            $colour = $item.Value
            if ($colour -is [Object[]]) {
                $r, $g, $b = $colour
            }
            else {
                $RGB = [Drawing.Color]::$Colour
                if ($RGB -is [Drawing.Color]) {
                    $r = $RGB.R
                    $g = $RGB.G
                    $b = $RGB.B
                }
            }
            switch ($item.Name) {
                "Foreground" { $op = 38 }
                "Background" { $op = 48 }
            }
            $enable += "`e[${op};2;${r};${g};${b}m"
        }
    }

    $wh_args = @{}
    foreach ($item in $colours.GetEnumerator()) {
        $colour = $item.Value -as [ConsoleColor]
        if ($null -ne $colour) {
            $wh_args[$item.Name] = $colour
        }
    }
    $wh_args, $enable
}

function get_text([ScriptBlock]$Script, [String]$Text) {
    if ($Script) {
        & $Script $Text
    } else {
        $Text
    }
}

function render_prompt ($layout) {
    foreach ($section in $layout) {
        $wh, $ansi = get_colour $section.Foreground $section.Background
        $text = get_text $section.Script $section.Text
        if (!$text) {
            continue
        }
        [PSCustomObject]@{Text=$text; WH=$wh; ANSI=$ansi}
    }
}

(render_prompt $p | % { "$($_.ANSI)$($_.Text)`e[0m" }) -join " "
