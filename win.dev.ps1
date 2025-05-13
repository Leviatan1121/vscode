#* CONFIG
$ORIGIN = "https://vscode.levihub.dev"
$yes_no = @("Yes", "No")

function Pause {
    Write-Host "`nPress any key to continue . . . "
    [Console]::ReadKey($true) | Out-Null
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
        Write-Host "`n[Arrows] Navigate  [Enter] Confirm  [Esc] Cancel"
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
                Clear-Host
                Write-Host "Program terminated" -ForegroundColor Green
                exit
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
            $prefix = if ($i -eq $current_index) { ">" } else { " " }
            $checkbox = if ($selected_indexes -contains $i) { "[x]" } else { "[ ]" }
            Write-Host "$prefix $checkbox $($menu_options[$i])"
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
                Clear-Host
                Write-Host "Program terminated" -ForegroundColor Green
                exit
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
    $local_extensions = @()
    $local_extensions_path = ".vscode/extensions.json"
    if (Test-Path $local_extensions_path) {
        $question = "Local extensions file found.`n`nHow do you want to proceed?"
        $options = @("Combine extensions", "Replace extensions", "Do nothing")
        $selected_index = Single-Select $question $options
        Clear-Host
        switch ($options[$selected_index]) {
            "Combine extensions" {
                #* COMBINE EXTENSIONS
                $local_json = Get-Content $local_extensions_path | ConvertFrom-Json

                if ($local_json.recommendations) {
                    $local_extensions = $local_json.recommendations
                    if ($local_extensions.Count -eq 1) {
                        Write-Host "Local: $($local_extensions.Count) extension`n"
                    } else {
                        Write-Host "Local: $($local_extensions.Count) extensions`n"
                    }
                    return @( 2, $local_extensions )
                }

                Write-Host "Local: no extensions found`n"
                return @( 1, $local_extensions )
            }
            "Replace extensions" {
                Write-Host "Replacing local extensions with remote extensions"
                return @( 1, $local_extensions )
            }
            "Do nothing" {
                Write-Host "Doing nothing"
                return @( 0, $local_extensions )
            }
        }
    } else {
        return @( 1, $local_extensions )
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













function Workspace {
    $workspace = irm "$ORIGIN/settings/workspace.code-workspace"
}
function Main {
    $selected_extension_packs = Select-Extension-Packs
    if (!$selected_extension_packs) {
        Write-Host "No extension packs selected"
    } else {
        $extensions_options = @("Local", "Remote", "Both")
        $result = Get-Local-Extensions
        $options_result = $result[0]
        $local_extensions = $result[1]

        $combined_extensions = @()
        switch ($extensions_options[$options_result]) {
            "Local" {
                return
            }
            "Remote" {
                $remote_extensions = Get-Remote-Extensions $selected_extension_packs
                $combined_extensions = $remote_extensions
            }
            "Both" {
                $remote_extensions = Get-Remote-Extensions $selected_extension_packs
                $combined_extensions = $local_extensions
                $combined_extensions += $remote_extensions
            }
        }
        $combined_extensions = $combined_extensions | Select-Object -Unique | Sort-Object
        Write-Host "`nTotal: $($combined_extensions.Count) unique extensions"
        Pause
        return


        Write-Host "`nLocal:"
        Write-Host $local_extensions

        $extensions = @()
        if (!$local_extensions -eq 1) {
            $extensions += $local_extensions
        }
        if ($remote_extensions.Count -gt 0) {
            $extensions += $remote_extensions
        }

        if ($extensions.Count -gt 0) {
            $extensions = $extensions | Select-Object -Unique | Sort-Object
            Write-Host "`nTotal: $($extensions.Count) extensions`n"
        } else {
            Write-Host "No extensions found"
        }
    }

    #Workspace
}
Main