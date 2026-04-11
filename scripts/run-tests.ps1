Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$DebugPreference = 'SilentlyContinue'
$PSNativeCommandUseErrorActionPreference = $true

try {
    if (Get-Command swift -ErrorAction SilentlyContinue) {
        Write-Output "Running native swift test"
        swift test
        if ($LASTEXITCODE -ne 0) {
            throw "swift test exited with code $LASTEXITCODE"
        }
    } else {
        Write-Output "Native Swift not found; running tests in Docker (swift:5.9)"
        docker run --rm -v "${PWD}:/workspace" -w /workspace swift:5.9 /bin/bash -lc "swift test"
        if ($LASTEXITCODE -ne 0) {
            throw "Docker swift test exited with code $LASTEXITCODE"
        }
    }
} catch {
    Write-Error "Test run failed: $_"
    exit 1
}
