# Opción 1: Usando Invoke-Expression (IEX)
irm "http://127.0.0.1:3000/test.bat" | iex

# Opción 2: Usando el operador de llamada &
& ([scriptblock]::Create((irm "http://127.0.0.1:3000/test.bat")))