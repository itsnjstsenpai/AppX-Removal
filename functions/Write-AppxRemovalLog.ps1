function Write-AppxRemovalLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $levelTag = if ($Level -eq "INFO") { "" } else { "[$Level] " }
    $line = "[$timestamp] $levelTag[AppX] $Message"
    $color = switch ($Level) {
        "WARN" { "Yellow" }
        "ERROR" { "Red" }
        default { "Gray" }
    }
    Write-Host $line -ForegroundColor $color

    try {
        if ([string]::IsNullOrWhiteSpace($script:AppxRemovalLogPath)) {
            $logDirectory = Join-Path $env:LOCALAPPDATA "AppX-Removal\logs"
            $script:AppxRemovalLogPath = Join-Path $logDirectory "AppX-Removal_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"
        }

        $logDirectory = Split-Path -Path $script:AppxRemovalLogPath -Parent
        if (-not (Test-Path -LiteralPath $logDirectory)) {
            New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
        }
        Add-Content -LiteralPath $script:AppxRemovalLogPath -Value $line -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        Write-Warning "Unable to write AppX-Removal log: $($_.Exception.Message)"
    }
}
