# Configuration
```ps1
$ORIGIN = "https://vscode.levihub.dev"
$combine_replace = @("Combine extensions", "Replace extensions")
$yes_no = @("Yes", "No")
```

# Extension Packs

## Select Pack/Packs/None
```ps1
```

## Display selected Packs
```ps1
```

## Preview of extensions.json
```ps1
```

# Workspace File

## See the file (Yes/No)
```ps1
```

## Preview: Use the file? (Yes/No)
```ps1
```

## Name the file
```ps1
if ($selectedIndex -eq 0) {
    New-Item -ItemType Directory -Force -Path ".vscode" | Out-Null

    while (1) {
        try {
            # Prompt user for workspace name
            $workspaceName = Read-Host -Prompt "Enter a name for your workspace"
            # Replace "Workspace Title" with the user-provided name
            $fileConent = $workspace.Replace("Workspace Title", $workspaceName)
            # Write content to the workspace file
            $fileConent | Out-File -FilePath ".vscode/$workspaceName.code-workspace" -Encoding UTF8 -NoNewline -ErrorAction Stop
            break
        } catch {
            Write-Host "`nError creating Workspace file: Invalid filename or insufficient permissions." -ForegroundColor Red
            Write-Host "+ Details: $_" -ForegroundColor Red
            Write-Host "`nPress any key to continue . . . "
            [Console]::ReadKey($true) | Out-Null
        }
    }
}
```