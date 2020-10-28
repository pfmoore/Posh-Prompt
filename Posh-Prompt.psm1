function add_colour($Type, $Colour) {
    if ($null -eq $Colour) {
        return $null
    }
    $cc = ($Colour -as [ConsoleColor])
    if ($cc -is [ConsoleColor]) {
        @{$Type=$cc}
    }
    elseif ($host.UI.SupportsVirtualTerminal) {
        if ($Colour -is [Object[]]) {
            $r, $g, $b = $Colour
        }
        else {
            $RGB = [Drawing.Color]::$Colour
            if ($RGB -is [Drawing.Color]) {
                $r = $RGB.R
                $g = $RGB.G
                $b = $RGB.B
            }
        }
        switch ($Type) {
            "Foreground" { $op = 38 }
            "Background" { $op = 48 }
            default { raise "Invalid colour type: $Type" }
        }
        "`e[${op};2;${r};${g};${b}m"
    }
}

function Write-ColouredText($Foreground, $Background, $Text) {
    $write_params = @{NoNewline=$true}
    $suffix = ""
    $colour = add_colour "Foreground" $Foreground
    if ($null -eq $colour) {
        $text = $text
    }
    elseif ($colour -is [String]) {
        $Text = $colour + $text
        $suffix = "`e[0m"
    }
    else {
        $write_params = $write_params + $colour
    }
    $colour = add_colour "Background" $Background
    if ($null -eq $colour) {
        $text = $text
    }
    elseif ($colour -is [String]) {
        $Text = $colour + $text
        $suffix = "`e[0m"
    }
    else {
        $write_params = $write_params + $colour
    }

    Write-Host @write_params ($Text + $suffix)
}

$sections = @(
    @{
        Text = "PS "
        Foreground = "Cyan"
    },
    @{
        Text = { Get-Date -uformat "%H:%M" }
        Foreground = "Red"
        Separator = " "
    },
    @{
        Condition = { Test-Path env:VIRTUAL_ENV }
        Text = { "($(Split-Path -Leaf $env:VIRTUAL_ENV))" }
        Foreground = "Green"
        Separator = " "
    },
    @{
        Text = {
            $dur = (Get-History -ea 0 -Count 1).Duration
            if ($dur) {
                $fmt = 'mm\:ss\.fff'
                if ($dur.Hours -gt 0) { $fmt = 'hh\:' + $fmt }
                "{$($dur.ToString($fmt))}"
            }
        }
        Foreground = "Blue"
        Separator = " "
    },
    @{
        Text = { (Get-Location).ProviderPath }
        Foreground = "Yellow"
    },
    @{
        Text = { "-" * $NestedPromptLevel }
        Foreground = "Blue"
    }
)

function prompt {
    foreach ($section in $sections) {
        if ($section.ContainsKey("Condition")) {
            $condition = (& $section.Condition)
            if (!$condition) {
                continue
            }
        }
        $text = $section.Text
        if ($text -is [ScriptBlock]) {
            $text = (& $text)
        }
        if ($section.ContainsKey("Separator")) {
            $text = $text + $section.Separator
        }
        Write-ColouredText -Foreground $section.Foreground -Background $section.Background -Text $text
    }
    Write-Host
    ">"
}
