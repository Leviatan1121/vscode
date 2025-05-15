#* CONFIG
$ORIGIN = "https://vscode.levihub.dev"
$yes_no = @("Yes", "No")

function Cursor {
    param (
        [bool]$visible
    )
    [Console]::CursorVisible = $visible
}
function Exit-Program {
    Clear-Host
    Write-Host "Program terminated" -ForegroundColor Green
    Cursor $true
    exit
}

function Pause {
    Write-Host "`nPress any key to continue . . . "
    [Console]::ReadKey($true) | Out-Null
    Clear-Host
}

#* FILE FUNCTIONS
function Check-Folder {
    if (!(Test-Path ".vscode")) {
        New-Item ".vscode" -ItemType Directory | Out-Null
    }
}
function Save-File {
    param (
        [string]$file_path,
        [string]$file_content
    )
    try {
        $file_content | Out-File $file_path -Encoding UTF8 -NoNewline
        return $false
    } catch {
        return $_
    }
}

function Single-Select-Menu {
    param (
        [string]$question,
        [string[]]$menu_options,
        [int]$selected_index
    )
    Clear-Host
    Write-Host $question
    for ($i = 0; $i -lt $menu_options.Length; $i++) {
        if ($i -eq $selected_index) {
            Write-Host "> $($menu_options[$i])" -ForegroundColor Cyan
        } else {
            Write-Host "  $($menu_options[$i])"
        }
    }
}

function Single-Select {
    param (
        [string]$question,
        [array]$menu_options
    )
    $selected_index = 0
    while ($true) {
        Single-Select-Menu $question $menu_options $selected_index
        Write-Host "`n[Arrows] Navigate  [Enter] Confirm  [Esc] Exit"
        $key = [Console]::ReadKey($true)

        switch ($key.Key) {
            "UpArrow" {
                $selected_index = ($selected_index - 1 + $menu_options.Length) % $menu_options.Length
            }
            "DownArrow" {
                $selected_index = ($selected_index + 1) % $menu_options.Length
            }
            "Enter" {
                return $selected_index
            }
            "Escape" {
                Exit-Program
            }
        }
    }
}

function Multi-Select {
    param (
        [string]$question,
        [array]$menu_options
    )
    $selected_indexes = [System.Collections.ArrayList]@()
    $current_index = 0
    while ($true) {
        Clear-Host
        Write-Host $question
        for ($i = 0; $i -lt $menu_options.Length; $i++) {
            $string_parts = @(
                @(if ($i -eq $current_index) { ">" } else { " " }, "Cyan"),
                @(" ["),
                @(if ($selected_indexes -contains $i) { "x" } else { " " }, "Cyan"),
                @("] $($menu_options[$i])`n")
            )
            $string_parts | ForEach-Object {
                if ($_[1]) {
                    Write-Host $_[0] -ForegroundColor $_[1] -NoNewline
                } else {
                    Write-Host $_[0] -NoNewline
                }
            }
        }
        Write-Host "`n[Arrows] Navigate  [Space] Select/Deselect  [Enter] Confirm  [Esc] Exit"

        $key = [Console]::ReadKey($true)

        switch ($key.Key) {
            "UpArrow" {
                $current_index = ($current_index - 1 + $menu_options.Length) % $menu_options.Length
            }
            "DownArrow" {
                $current_index = ($current_index + 1) % $menu_options.Length
            }
            "Spacebar" {
                if ($selected_indexes -contains $current_index) {
                    $selected_indexes.Remove($current_index)
                } else {
                    [void]$selected_indexes.Add($current_index)
                }
            }
            "Enter" {
                if ($selected_indexes.Count -gt 0) {
                    return $selected_indexes
                } else {
                    return -1
                }
            }
            "Escape" {
                Exit-Program
            }
        }
    }
}

function Select-Extension-Packs {
    $extension_packs_names = irm "$ORIGIN/extensions.json"
    $selected_indexes = Multi-Select "Select extension packs:" $extension_packs_names
    switch ($selected_indexes) {
        -1 {
            return 0
        }
        default {
            return @($selected_indexes | ForEach-Object { $extension_packs_names[$_].ToLower() }) | Select-Object -Unique | Sort-Object
        }
    }
}

$EXTENSION_ACTION = @{
    COMBINE = 0
    REPLACE = 1
    DO_NOTHING = 2
}

function Get-Local-Extensions {
    param (
        [string]$local_extensions_path
    )
    $local_extensions = @()
    if (Test-Path $local_extensions_path) {
        $question = "Local extensions file found.`n`nHow do you want to proceed?"
        $options = @("Combine extensions", "Replace extensions", "Do nothing")
        $selected = Single-Select $question $options
        Clear-Host

        if ($selected -eq $EXTENSION_ACTION.COMBINE) {
            $json = Get-Content $local_extensions_path | ConvertFrom-Json

            if ($json.recommendations) {
                $extensions = $json.recommendations
                if ($local_extensions.Count -eq 1) {
                    Write-Host "Local: $($extensions.Count) extension`n"
                } else {
                    Write-Host "Local: $($extensions.Count) extensions`n"
                }
            } else {
                Write-Host "Local: no extensions found`n"
                return @( $EXTENSION_ACTION.REPLACE, $extensions )
            }
        }
        return @( $selected, $extensions )
    }
    return @( $EXTENSION_ACTION.REPLACE, $extensions )
}

function Get-Remote-Extensions {
    param (
        [array]$selected_extension_packs
    )

    Write-Host "Remote:"

    $remote_extensions = @()
    foreach ($extension_pack in $selected_extension_packs) {
        $pack_path = "$ORIGIN/settings/extensions/$extension_pack/extensions.json"
        $json_content = (irm $pack_path).ToString().Split([Environment]::NewLine) |
            Where-Object { $_ -notmatch '^\s*//.*' } |
            Where-Object { $_ -notmatch '/\*.*\*/' } |
            ForEach-Object { $_ -replace '//.*$', '' } |
            Where-Object { $_.Trim() -ne '' }

        $extensions = ($json_content -join "`n" | ConvertFrom-Json).recommendations
        if ($extensions.Count -eq 0) {
            Write-Host " - ${extension_pack}: $($extensions.Count) extensions (will skip this pack)"
        } elseif ($extensions.Count -eq 1) {
            Write-Host " - ${extension_pack}: $($extensions.Count) extension"
            $remote_extensions += $extensions
        } else {
            Write-Host " - ${extension_pack}: $($extensions.Count) extensions"
            $remote_extensions += $extensions
        }
    }
    return $remote_extensions
}

function Save-Extensions {
    param (
        [array]$extensions,
        [string]$extensions_path
    )
    $INDENT = "    "
    $EXTENSION_INDENT = "        "

    $json = "{`n" +
            "$INDENT""recommendations"": [`n" +
            (($extensions | Where-Object { $_ } | ForEach-Object { "$EXTENSION_INDENT""$_""" }) -join ",`n") +
            "`n$INDENT]`n" +
            "}"

    # Verificar que el JSON no está vacío
    if ([string]::IsNullOrWhiteSpace($json)) {
        Write-Host "Error: The generated JSON is empty" -ForegroundColor Red
        Pause
        return
    }
    $options = @("Yes", "No")
    $selected = Single-Select "Preview of extensions.json:`n`n$json`n`nSave this file?" $options
    if ($options[$selected] -eq "Yes") {
        Check-Folder
        Save-File $extensions_path $json
        Write-Host "Extensions saved successfully" -ForegroundColor Green
    } else {
        Write-Host "Extensions not saved" -ForegroundColor Red
    }
}


function Get-Remote-Workspace {
    $err = $false
    $workspace = $null
    try {
        $workspace = irm "$ORIGIN/settings/workspace.code-workspace"
        try {
            $workspace | ConvertFrom-Json
        } catch {
            $err = "Error parsing the workspace file: The workspace file is not a valid JSON.`n+ Details: $_"
        }
    } catch {
        $err = "Error getting a workspace file from the server: Failed connecting to the server or file not found.`n+ Details: $_"
    }

    if ($err) {
        Write-Host "`n$err" -ForegroundColor Red
        Pause
        return @( $false, $workspace )
    } else {
        return @( $true, $workspace )
    }
}
function Use-Workspace {
    param (
        [string]$workspace
    )
    $options = @("Yes", "No")
    $selected = Single-Select "There is a workspace file in the server.`nDo you want to load it?" $options
    if ($options[$selected] -eq "Yes") {
        $selected = Single-Select "Preview of workspace.code-workspace:`n`n$workspace`n`nUse this workspace file?" $options
        if ($options[$selected] -eq "Yes") {
            return $true
        }
    }
    return $false
}
function Save-Workspace {
    param (
        [string]$workspace
    )
    $workspace_name = $null
    $options = @("Yes", "No")

    Check-Folder
    while ($workspace_name -eq $null) {
        Clear-Host
        $workspace_name = Read-Host -Prompt "Name your workspace (leave empty to cancel)"
        if ([string]::IsNullOrWhiteSpace($workspace_name)) {
            Write-Host "Workspace creation canceled."
            return
        }

        $err = Save-File ".vscode/$workspace_name.code-workspace.tmp" ""
        if ($err) {
            $question = "Error creating a Workspace file with name $workspace_name: Invalid filename or insufficient permissions.`nDo you want to try again?"
            $selected = Single-Select $question $options
            if ($options[$selected] -eq "No") {
                Write-Host "Workspace creation canceled."
                return
            }
            $workspace_name = $null
        }
    }

    Remove-Item -Path ".vscode/$workspace_name.code-workspace.tmp" -Force

    $question = "Remove any other Workspace files in the .vscode folder?"
    $selected = Single-Select $question $options
    if ($options[$selected] -eq "Yes") {
        $old_workspaces = Get-ChildItem -Path ".vscode/" -Filter "*.code-workspace" -File
        if ($old_workspaces.Count -gt 0) {
            foreach ($file in $files) {
                Remove-Item -Path $file.FullName -Force
            }
        }
    }

    $file_data = $workspace.Replace("Workspace Title", $workspace_name)
    $save_error = Save-File ".vscode/$workspace_name.code-workspace" $file_data
    if ($save_error) {
        Write-Host "Error saving the Workspace file.`n+ Path: .vscode/$workspace_name.code-workspace`n+ Details: $save_error" -ForegroundColor Red
    } else {
        Write-Host "Workspace saved successfully" -ForegroundColor Green
    }
}
function Main {
    $selected_extension_packs = Select-Extension-Packs
    if (!$selected_extension_packs) {
        Write-Host "No extension packs selected"
    } else {
        $LOCAL_EXTENSIONS_PATH = ".vscode/extensions.json"
        $selected, $local_extensions = Get-Local-Extensions $LOCAL_EXTENSIONS_PATH

        $extensions = @()
        switch ($selected) {
            $EXTENSION_ACTION.DO_NOTHING {
                return
            }
            $EXTENSION_ACTION.REPLACE {
                $extensions = Get-Remote-Extensions $selected_extension_packs
            }
            $EXTENSION_ACTION.COMBINE {
                $remote_extensions = Get-Remote-Extensions $selected_extension_packs
                $extensions = $local_extensions + $remote_extensions
            }
        }

        $extensions = $extensions | Select-Object -Unique | Sort-Object
        Write-Host "`nTotal: $($extensions.Count) unique extensions"

        Pause
        Save-Extensions $extensions $LOCAL_EXTENSIONS_PATH
        Pause
    }
    $workspace_is_valid, $workspace = Get-Remote-Workspace
    if ($workspace_is_valid) {
        $use = Use-Workspace $workspace
        if (!$use) { Exit-Program }
        Save-Workspace $workspace
        Pause
    }
}
Cursor $false
Main
Exit-Program