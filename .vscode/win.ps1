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

# Definir las opciones
$ide_options = @("Cursor", "Visual Studio Code")
$env_options = @("Tauri", "Clang", "Common")
$yes_no_options = @("Yes", "No")
$no_yes_options = @("No", "Yes")

# 1) Selección del IDE
$selectedIndex = Select-Option -question "What IDE are you using?" -menuOptions $ide_options
$installCommand = $ide_options[$selectedIndex].ToLower()

# 2) Selección de environments
$selectedEnvironments = @()
do {
    $selectedIndex = Select-Option -question "Select the environment:" -menuOptions $env_options
    $selectedEnvironments += $env_options[$selectedIndex].ToLower()
    
    $selectedIndex = Select-Option -question "Add another environment?" -menuOptions $no_yes_options
} while ($no_yes_options[$selectedIndex] -eq "Yes")

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
        Write-Host "Error al procesar el JSON: $_"
        Write-Host "Por favor, revisa el archivo debug_json.txt para ver el contenido"
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