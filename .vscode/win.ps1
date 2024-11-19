# Definir las opciones
$options = @("Tauri", "Clang", "Common")
$selectedIndex = 0

# Función para mostrar el menú
function Show-Menu {
    Clear-Host
    for ($i = 0; $i -lt $options.Length; $i++) {
        if ($i -eq $selectedIndex) {
            Write-Host "> $($options[$i])" -ForegroundColor Cyan
        } else {
            Write-Host "  $($options[$i])"
        }
    }
}

# Mostrar el menú y esperar la entrada del usuario
while ($true) {
    Show-Menu
    $key = [Console]::ReadKey($true)

    if ($key.Key -eq [ConsoleKey]::UpArrow) {
        $selectedIndex = ($selectedIndex - 1 + $options.Length) % $options.Length
    } elseif ($key.Key -eq [ConsoleKey]::DownArrow) {
        $selectedIndex = ($selectedIndex + 1) % $options.Length
    } elseif ($key.Key -eq [ConsoleKey]::Enter) {
        break
    }
}

# Ejecutar la acción según la opción seleccionada
switch ($options[$selectedIndex]) {
    "Tauri" {
        Copy-Item "tauri-extensions.json" "extensions.json"
    }
    "Clang" {
        Copy-Item ".vscode/clang-extensions.json" ".vscode/extensions.json"
    }
    "Common" {
        Copy-Item ".vscode/common-extensions.json" ".vscode/extensions.json"
    }
}