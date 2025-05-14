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
    $file_content | Out-File $file_path -Encoding UTF8 -NoNewline
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

function Get-Local-Extensions {
    param (
        [string]$local_extensions_path
    )
    $local_extensions = @()
    if (Test-Path $local_extensions_path) {
        $question = "Local extensions file found.`n`nHow do you want to proceed?"
        $options = @("Combine extensions", "Replace extensions", "Do nothing")
        $selected_index = Single-Select $question $options
        Clear-Host
        $ACTION = @{
            DO_NOTHING = 0
            REPLACE = 1
            COMBINE = 2
        }
        switch ($options[$selected_index]) {
            "Combine extensions" {
                #* COMBINE EXTENSIONS
                $json = Get-Content $local_extensions_path | ConvertFrom-Json

                if ($json.recommendations) {
                    $extensions = $json.recommendations
                    if ($local_extensions.Count -eq 1) {
                        Write-Host "Local: $($extensions.Count) extension`n"
                    } else {
                        Write-Host "Local: $($extensions.Count) extensions`n"
                    }
                    return @( $ACTION.COMBINE, $extensions )
                }

                Write-Host "Local: no extensions found`n"
                return @( $ACTION.REPLACE, $extensions )
            }
            "Replace extensions" {
                return @( $ACTION.REPLACE, $extensions )
            }
            "Do nothing" {
                Write-Host "Doing nothing"
                return @( $ACTION.DO_NOTHING, $extensions )
            }
        }
    } else {
        return @( $ACTION.REPLACE, $extensions )
    }
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


function Workspace {
    $workspace = irm "$ORIGIN/settings/workspace.code-workspace"
}
function Main {
    $selected_extension_packs = Select-Extension-Packs
    if (!$selected_extension_packs) {
        Write-Host "No extension packs selected"
    } else {
        $LOCAL_EXTENSIONS_PATH = ".vscode/extensions.json"
        $selected, $local_extensions = Get-Local-Extensions $LOCAL_EXTENSIONS_PATH

        $extensions = @()
        $options = @("Local", "Remote", "Both")
        switch ($options[$selected]) {
            "Local" {
                return
            }
            "Remote" {
                $remote_extensions = Get-Remote-Extensions $selected_extension_packs
                $extensions = $remote_extensions
            }
            "Both" {
                $remote_extensions = Get-Remote-Extensions $selected_extension_packs
                $extensions = $local_extensions + $remote_extensions
                #$extensions += $remote_extensions
            }
        }

        $extensions = $extensions | Select-Object -Unique | Sort-Object
        Write-Host "`nTotal: $($extensions.Count) unique extensions"

        Pause

        Save-Extensions $extensions $LOCAL_EXTENSIONS_PATH

        Pause

        return
    }

    #Workspace
}
Cursor $false
Main
Cursor $true