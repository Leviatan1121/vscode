$ORIGIN = "http://127.0.0.1:3000"
# Obtener el contenido JSON desde la URL usando Invoke-RestMethod (irm)
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

# 2) Selección de environments
$selectedIndices = Select-Multiple-Options -question "Select extension packs (use Arrow keys to navigate):" -menuOptions $env_options
if ($selectedIndices.Count -eq 0) {
    Write-Host "Operation cancelled"
    exit
}

$selectedEnvironments = @($selectedIndices | ForEach-Object { $env_options[$_].ToLower() })
Write-Host "Selected environments: $($selectedEnvironments -join ", ")"

# 3) Crear archivo combinado
$path = ".vscode/extensions"
$combinedExtensions = @()
if (!(Test-Path $path)) { New-Item -ItemType Directory -Force -Path $path | Out-Null }

foreach ($env in $selectedEnvironments) {
    $envPath = "$ORIGIN/$path/$env/extensions.json"
    try {
        $jsonContent = (irm $envPath).ToString().Split([Environment]::NewLine) | 
            Where-Object { $_ -notmatch '^\s*//.*' } |  
            Where-Object { $_ -notmatch '/\*.*\*/' } |  
            ForEach-Object { $_ -replace '//.*$', '' } |  
            Where-Object { $_.Trim() -ne '' }  
        
        $extensions = ($jsonContent -join "`n" | ConvertFrom-Json).recommendations
        $combinedExtensions += $extensions
        Write-Host "Extensions found: $($extensions.Count)"
    } catch {
        Write-Host ("Error loading " + $envPath + ": " + $_.Exception.Message)
        continue
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