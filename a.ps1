$files = Get-ChildItem -Path ".vscode/" -Filter "*.code-workspace" -File
if ($files.Count -gt 0) {
    foreach ($file in $files) {
        Remove-Item -Path $file.FullName -Force
    }
}