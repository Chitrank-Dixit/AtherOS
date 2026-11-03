[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputPath
)

# Read-only inventory. It does not enable features, start services, or install software.
$ErrorActionPreference = 'Continue'
$lines = [System.Collections.Generic.List[string]]::new()
function Add-Line([string]$Value) { $script:lines.Add($Value) }
function Add-Section([string]$Name) { Add-Line ''; Add-Line "== $Name ==" }
function Invoke-Check([string]$Name, [scriptblock]$Action) {
    try {
        $result = & $Action 2>&1 | Out-String
        $result = ($result -replace "`0", '').Trim()
        $result = [regex]::Replace($result, '(?i)[A-Z]:\\Users\\[^\r\n;]+', '<user-path>')
        $result = [regex]::Replace($result, '(?i)[A-Z]:\\Projects\\AetherOS', '<workspace>')
        if (-not $result) { $result = 'available; no detail returned' }
        Add-Line ("{0}: {1}" -f $Name, ($result -replace '[\r\n]+', '; '))
    } catch { Add-Line ("{0}: unavailable ({1})" -f $Name, $_.Exception.Message) }
}

Add-Line 'Aether Linux host diagnostics (read-only)'
Add-Line ("Collected UTC: {0}" -f [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))
Add-Section 'Windows'
Invoke-Check 'OS version' { Get-CimInstance Win32_OperatingSystem -ErrorAction Stop | Select-Object Caption, Version, BuildNumber }
Invoke-Check 'CPU virtualization visibility' { Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1 Name, VirtualizationFirmwareEnabled, VMMonitorModeExtensions }
Invoke-Check 'Hypervisor launch status' { bcdedit.exe /enum '{current}' | Select-String -Pattern 'hypervisorlaunchtype' }
Invoke-Check 'Memory (GiB)' { $computer = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop; [math]::Round($computer.TotalPhysicalMemory / 1GB, 1) }
Invoke-Check 'System drive free space (GiB)' { Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'" -ErrorAction Stop | Select-Object DeviceID, @{Name='FreeGiB';Expression={[math]::Round($_.FreeSpace / 1GB, 1)}} }

Add-Section 'WSL'
Invoke-Check 'WSL status and distributions' { wsl.exe --list --verbose }
Invoke-Check 'WSL version' { wsl.exe --version }

Add-Section 'Virtualization and container tooling'
foreach ($tool in @('docker', 'podman', 'qemu-system-x86_64', 'VBoxManage', 'vmrun', 'Get-VM')) {
    $cmd = Get-Command $tool -ErrorAction SilentlyContinue
    if (-not $cmd) { Add-Line "${tool}: unavailable"; continue }
    if ($tool -eq 'Get-VM') {
        Invoke-Check 'Hyper-V VM inventory (if supported)' { Get-VM | Select-Object Name, State }
        continue
    }
    Invoke-Check $tool { & $cmd.Source --version }
}
Invoke-Check 'Docker engine (read-only info query)' { docker info --format '{{.OSType}}/{{.Architecture}}' }
Invoke-Check 'Podman machine inventory (read-only)' { podman machine list }
Invoke-Check 'Hyper-V feature state (read-only)' { Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All | Select-Object FeatureName, State }

Add-Section 'Interpretation'
Add-Line 'Detected tools and settings do not prove that builders or VMs function safely.'
Add-Line 'No configuration, service, Windows feature, disk, or boot setting was changed.'
$report = $lines -join [Environment]::NewLine
if ($OutputPath) {
    $resolved = [System.IO.Path]::GetFullPath($OutputPath)
    if (Test-Path -LiteralPath $resolved) { throw "Refusing to overwrite existing report: $resolved" }
    $parent = Split-Path -Parent $resolved
    if (-not (Test-Path -LiteralPath $parent)) { throw "Output directory does not exist: $parent" }
    [System.IO.File]::WriteAllText($resolved, $report, [System.Text.UTF8Encoding]::new($false))
}
$report
