[CmdletBinding()]
param(
    [Parameter(ParameterSetName="Console")]
    [ConsoleColor]$ForegroundC,
    [Parameter(ParameterSetName="Drawing")]
    [System.Drawing.Color]$ForegroundD
)

Write-Host $PSCmdlet.ParameterSetName

Write-Host ($Foreground).GetType()
Write-Host $Foreground
