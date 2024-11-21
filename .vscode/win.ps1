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
        $key = [Console]::ReadKey($true)

        if ($key.Key -eq [ConsoleKey]::UpArrow) {
            $selectedIndex = ($selectedIndex - 1 + $menuOptions.Length) % $menuOptions.Length
        } elseif ($key.Key -eq [ConsoleKey]::DownArrow) {
            $selectedIndex = ($selectedIndex + 1) % $menuOptions.Length
        } elseif ($key.Key -eq [ConsoleKey]::Enter) {
            return $selectedIndex
        }
    }
}

# Nueva función para selección múltiple con checkboxes
function Select-Multiple-Options {
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
        Write-Host "`n[Space] Select/Deselect  [Enter] Confirm  [Esc] Cancel"

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

# Definir las opciones
$ide_options = @("Cursor", "Visual Studio Code")
$env_options = Get-ChildItem -Path ".vscode/extensions" -Directory | 
    Where-Object { Test-Path (Join-Path $_.FullName "extensions.json") } | 
    Select-Object -ExpandProperty Name
if ($env_options.Count -eq 0) {
    Write-Host "No se encontraron carpetas con archivo extensions.json en .vscode/extensions"
    exit
}
$yes_no_options = @("Yes", "No")
$no_yes_options = @("No", "Yes")

# 1) Selección del IDE
$selectedIndex = Select-Option -question "What IDE are you using?" -menuOptions $ide_options
$installCommand = $ide_options[$selectedIndex].ToLower()
if ($installCommand -eq "visual studio code") { $installCommand = "code" }

# 2) Selección de environments
$selectedIndices = Select-Multiple-Options -question "Select extension packs (use Arrow keys to navigate):" -menuOptions $env_options
if ($selectedIndices.Count -eq 0) {
    Write-Host "Operation cancelled"
    exit
}

$selectedEnvironments = @($selectedIndices | ForEach-Object { $env_options[$_].ToLower() })

# 3) Crear archivo combinado
$path = ".vscode/extensions"
$combinedExtensions = @()

foreach ($env in $selectedEnvironments) {
    $envPath = "$path/$env/extensions.json"
    if (Test-Path $envPath) {
        $jsonContent = Get-Content $envPath | 
            Where-Object { $_ -notmatch '^\s*//.*' } |  
            Where-Object { $_ -notmatch '/\*.*\*/' } |  
            ForEach-Object { $_ -replace '//.*$', '' } |  
            Where-Object { $_.Trim() -ne '' }  
        
        $extensions = ($jsonContent -join "`n" | ConvertFrom-Json).recommendations
        $combinedExtensions += $extensions
    }
}

# Eliminar duplicados y crear nuevo objeto JSON
$uniqueExtensions = $combinedExtensions | Select-Object -Unique | Sort-Object

# Verificar que tenemos extensiones
Write-Host "Extensiones encontradas: $($uniqueExtensions.Count)"

# Crear el JSON con formato exacto
$newJson = "{`n" + 
           "    ""recommendations"": [`n" +
           (($uniqueExtensions | Where-Object { $_ } | ForEach-Object { "        ""$_""" }) -join ",`n") +
           "`n    ]`n" +
           "}"

# Verificar que el JSON no está vacío
if ([string]::IsNullOrWhiteSpace($newJson)) {
    Write-Host "Error: JSON generado está vacío"
    return
}

# Crear el archivo final
New-Item -ItemType Directory -Force -Path ".vscode" | Out-Null
$newJson | Out-File ".vscode/extensions.json" -Encoding UTF8 -NoNewline

#* 4) Preguntar por instalación
$selectedIndex = Select-Option -question "Install extensions?" -menuOptions $no_yes_options
if ($no_yes_options[$selectedIndex] -eq "Yes") {
    # Leer el archivo y eliminar comentarios antes de convertir
    $jsonContent = (Get-Content .vscode/extensions.json | 
        Where-Object { $_ -notmatch '^\s*//.*' } |  # Elimina comentarios de línea completa
        Where-Object { $_ -notmatch '/\*.*\*/' } |  # Elimina comentarios de bloque
        ForEach-Object { $_ -replace '//.*$', '' } |  # Elimina comentarios al final de la línea
        Where-Object { $_.Trim() -ne '' }  # Elimina líneas vacías
    ) -join "`n"
    
    try {
        $extensions = ($jsonContent | ConvertFrom-Json).recommendations
        
        foreach ($ext in $extensions) {
            Write-Host "Installing $ext";
            Start-Process -FilePath $installCommand -ArgumentList "--install-extension", $ext -NoNewWindow -Wait;
        }
    } catch {
        Write-Host "Error al procesar el JSON: $_" -ForegroundColor Red
        Write-Host "Contenido del JSON:`n$jsonContent"  
    }
}

# 5) Preguntar por limpieza
$selectedIndex = Select-Option -question "Delete unused files?" -menuOptions $yes_no_options
if ($yes_no_options[$selectedIndex] -eq "Yes") {
    Write-Host "Deleting..."
    # Eliminar la carpeta @extensions y el propio script
    if (Test-Path ".vscode/extensions") { Remove-Item ".vscode/extensions" -Recurse -Force }
    $MyInvocation.MyCommand.Path | Remove-Item -Force
}

Write-Host "Done."