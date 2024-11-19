@echo off
setlocal enabledelayedexpansion

:: Definir las opciones
set options[0]=Tauri
set options[1]=Clang
set options[2]=Common
set selectedIndex=0

:menu
cls
echo Selecciona una opcion:
for /L %%i in (0,1,2) do (
    if !selectedIndex! equ %%i (
        echo > !options[%%i]!
    ) else (
        echo   !options[%%i]!
    )
)

:: Esperar la entrada del usuario
set /p choice="Usa las teclas 1, 2 o 3 para seleccionar y presiona Enter: "

:: Cambiar la opción seleccionada
if "%choice%"=="1" set selectedIndex=0
if "%choice%"=="2" set selectedIndex=1
if "%choice%"=="3" set selectedIndex=2

:: Ejecutar la acción según la opción seleccionada
if !selectedIndex! equ 0 (
    copy .vscode\tauri-extensions.json .vscode\extensions.json
) else if !selectedIndex! equ 1 (
    copy .vscode\clang-extensions.json .vscode\extensions.json
) else if !selectedIndex! equ 2 (
    copy .vscode\common-extensions.json .vscode\extensions.json
)

endlocal