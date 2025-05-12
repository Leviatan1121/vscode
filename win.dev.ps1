#* Configuration
$ORIGIN = "https://vscode.levihub.dev"
$combine_replace = @("Combine extensions", "Replace extensions")
$yes_no = @("Yes", "No")



#* Helper Functions
function Get-JsonWithoutComments {
    param (
        [string]$jsonContent
    )
}


#! REFACTOR
$env_options = irm "$ORIGIN/extensions.json"
# Iterar sobre cada elemento del array
foreach ($extension in $env_options) {
    Write-Host "Extensión: $extension"
    # Aquí puedes agregar la lógica que necesites para cada extensión
}

$selectedIndex = 0

# Función para mostrar el menú
function Show-Menu {
    param (
        [string]$question,
        [string[]]$menuOptions,
        [int]$selectedIndex
    )
    Clear-Host
    Write-Host $question
    for ($i = 0; $i -lt $menuOptions.Length; $i++) {
        if ($i -eq $selectedIndex) {
            Write-Host "> $($menuOptions[$i])" -ForegroundColor Cyan
        } else {
            Write-Host "  $($menuOptions[$i])"
        }
    }
}

# Función para manejar la selección del menú
function Select-Option {
    param (
        [string]$question,
        [string[]]$menuOptions
    )
    $selectedIndex = 0
    while ($true) {
        Show-Menu -question $question -menuOptions $menuOptions -selectedIndex $selectedIndex
        Write-Host "`n[Arrows] Select  [Enter] Confirm  [Esc] Cancel"
        $key = [Console]::ReadKey($true)

        if ($key.Key -eq [ConsoleKey]::UpArrow) {
            $selectedIndex = ($selectedIndex - 1 + $menuOptions.Length) % $menuOptions.Length
        } elseif ($key.Key -eq [ConsoleKey]::DownArrow) {
            $selectedIndex = ($selectedIndex + 1) % $menuOptions.Length
        } elseif ($key.Key -eq [ConsoleKey]::Enter) {
            return $selectedIndex
        } elseif ($key.Key -eq [ConsoleKey]::Escape) {
            return -1
        }
    }
}

# Nueva función para selección múltiple con checkboxes
function Select-Multiple {
    param (
        [string]$question,
        [string[]]$menuOptions
    )
    $selectedIndices = [System.Collections.ArrayList]@()
    $currentIndex = 0

    while ($true) {
        Clear-Host
        Write-Host $question
        for ($i = 0; $i -lt $menuOptions.Length; $i++) {
            $prefix = if ($i -eq $currentIndex) { ">" } else { " " }
            $checkbox = if ($selectedIndices -contains $i) { "[x]" } else { "[ ]" }
            Write-Host "$prefix $checkbox $($menuOptions[$i])"
        }
        Write-Host "`n[Arrows] Navigate  [Space] Select/Deselect  [Enter] Confirm  [Esc] Cancel"

        $key = [Console]::ReadKey($true)

        switch ($key.Key) {
            "UpArrow" {
                $currentIndex = ($currentIndex - 1 + $menuOptions.Length) % $menuOptions.Length
            }
            "DownArrow" {
                $currentIndex = ($currentIndex + 1) % $menuOptions.Length
            }
            "Spacebar" {
                if ($selectedIndices -contains $currentIndex) {
                    $selectedIndices.Remove($currentIndex)
                } else {
                    [void]$selectedIndices.Add($currentIndex)
                }
            }
            "Enter" {
                if ($selectedIndices.Count -gt 0) {
                    return $selectedIndices
                }
            }
            "Escape" {
                return @()
            }
        }
    }
}

# 2) Selección de environments
$selectedIndexes = Select-Multiple -question "Select extension packs:" -menuOptions $env_options
if ($selectedIndexes.Count -eq 0) {
    Write-Host "`nOperation cancelled"
    return
}


Clear-Host
$selectedEnvironments = @($selectedIndexes | ForEach-Object { $env_options[$_].ToLower() })

# 3) Crear archivo combinado
$combinedExtensions = @()

# Primero, verificar y cargar extensiones locales si existen
$localExtensionsPath = ".vscode/extensions.json"
if (Test-Path $localExtensionsPath) {
    $selectedIndex = Select-Option -question "Local extensions file found.`nDo you want to combine or replace local extensions?" -menuOptions $combine_replace
    Clear-Host
    if ($selectedIndex -eq -1) {
        Write-Host "`nOperation cancelled"
        return
    } elseif ($combine_replace[$selectedIndex] -eq "Combine extensions") {
        try {
            $localContent = (Get-Content $localExtensionsPath |
                Where-Object { $_ -notmatch '^\s*//.*' } |  # Elimina comentarios de línea completa
                Where-Object { $_ -notmatch '/\*.*\*/' } |  # Elimina comentarios de bloque
                ForEach-Object { $_ -replace '//.*$', '' } |  # Elimina comentarios al final de la línea
                Where-Object { $_.Trim() -ne '' }  # Elimina líneas vacías
            ) -join "`n"
            if ($localContent) {
                $localContent = $localContent | ConvertFrom-Json
                if ($localContent.recommendations) {
                    $combinedExtensions += $localContent.recommendations
                    $combinedExtensions = $combinedExtensions | Select-Object -Unique | Sort-Object
                    Write-Host "Local: $($combinedExtensions.Count) extensions`n"
                }
            }
        } catch {
            Write-Host "Error loading local extensions: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Continuar con las extensiones del servidor
Write-Host "Packs:"
foreach ($env in $selectedEnvironments) {
    $envPath = "$ORIGIN/settings/extensions/$env/extensions.json"
    try {
        $jsonContent = (irm $envPath).ToString().Split([Environment]::NewLine) |
            Where-Object { $_ -notmatch '^\s*//.*' } |
            Where-Object { $_ -notmatch '/\*.*\*/' } |
            ForEach-Object { $_ -replace '//.*$', '' } |
            Where-Object { $_.Trim() -ne '' }

        $extensions = ($jsonContent -join "`n" | ConvertFrom-Json).recommendations
        $combinedExtensions += $extensions
        Write-Host " - ${env}: $($extensions.Count) extensions"
    } catch {
        Write-Host ("Error loading " + $envPath + ": " + $_.Exception.Message) -ForegroundColor Red
        continue
    }
}

# Eliminar duplicados y crear nuevo objeto JSON
$uniqueExtensions = $combinedExtensions | Select-Object -Unique | Sort-Object

# Verificar que tenemos extensiones
Write-Host "`nTotal: $($uniqueExtensions.Count) unique extensions"

# Esperar que el usuario presione una tecla para continuar
Write-Host "`nPress any key to continue . . . "
[Console]::ReadKey($true) | Out-Null

# Crear el JSON con formato exacto
$newJson = "{`n" +
           "    ""recommendations"": [`n" +
           (($uniqueExtensions | Where-Object { $_ } | ForEach-Object { "        ""$_""" }) -join ",`n") +
           "`n    ]`n" +
           "}"

# Verificar que el JSON no está vacío
if ([string]::IsNullOrWhiteSpace($newJson)) {
    Write-Host "Error: JSON generated is empty" -ForegroundColor Red
    return
}

# Crear el archivo final
$selectedIndex = Select-Option -question "Preview of extensions.json:`n$newJson`n`nSave this file?" -menuOptions $yes_no
if ($selectedIndex -eq 0) {
    New-Item -ItemType Directory -Force -Path ".vscode" | Out-Null
    $newJson | Out-File $localExtensionsPath -Encoding UTF8 -NoNewline
}

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

Write-Host "Done."