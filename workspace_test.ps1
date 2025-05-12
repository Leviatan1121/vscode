# Preguntar si se quiere guardar el workspace
try {
    $workspace = irm "$ORIGIN/settings/workspace.code-workspace"
    if ($workspace) {
        $selectedIndex = Select-Option -question "There is a Workspace file in the server.`nDo you want to see it?" -menuOptions $yes_no
        if ($selectedIndex -eq 0) {
            # Get workspace from server
            $selectedIndex = Select-Option -question "Preview of Workspace file:`n$workspace`n`nUse this workspace file?" -menuOptions $yes_no
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
        }
    }
} catch {
    Write-Host "Error loading workspace: $($_.Exception.Message)" -foregroundcolor red
}