#* CONFIG
$ORIGIN = "https://vscode.levihub.dev"
$combine_replace = @("Combine extensions", "Replace extensions")
$yes_no = @("Yes", "No")

#* FILE FUNCTIONS


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
        Write-Host "`n[Arrows] Navigate  [Space] Select/Deselect  [Enter] Confirm  [Esc] Cancel"

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
                return -2
                return @()
            }
        }
    }
}

function Extensions {
    $extension_packs_names = irm "$ORIGIN/extensions.json"

    $selectedIndexes = Multi-Select "Select extension packs:" $extension_packs_names
    Write-Host "$selectedIndexes"



    switch ($selectedIndexes) {
        -2 {
            Write-Host "`nOperation cancelled"
            return "cenceled"
        }
        -1 {
            Write-Host "`nNo extension packs selected"
            return "none selected"
        }
        default {
            Write-Host "`nSelected extension packs:"
            foreach ($index in $selectedIndexes) {
                Write-Host "- $($extension_packs_names[$index])"
            }
            return "continue"
        }
    }
}













function Workspace {
    $workspace = irm "$ORIGIN/settings/workspace.code-workspace"
}
function Main {
    $res = Extensions
    Write-Host $res
    #Workspace
}
Main