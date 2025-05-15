try {
    $a = irm "https://levihub.dev/aaaa"# -ErrorAction Stop
    Write-Host "All good"
} Catch {
    Write-Host "Catch"
} Finally {
    Write-Host "Finally"
}