try {
    if (Get-Command swift -ErrorAction SilentlyContinue) {
        Write-Output "Running native swift test"
        swift test
    } else {
        Write-Output "Native Swift not found; running tests in Docker (swift:5.9)"
        docker run --rm -v "${PWD}:/workspace" -w /workspace swift:5.9 /bin/bash -lc "swift test"
    }
} catch {
    Write-Error "Test run failed: $_"
    exit 1
}
