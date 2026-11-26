@echo off
REM Criterio 1: commit con un error intencional en el boton Completar del frontend
cd /d "%~dp0"
powershell -NoProfile -Command "$p='public\app.js'; $t=[IO.File]::ReadAllText($p); if(-not $t.Contains('/completar`')){Write-Host 'El cambio ya estaba aplicado'; exit 0}; $t=$t.Replace('/completar`','/completado`'); [IO.File]::WriteAllText($p,$t,(New-Object Text.UTF8Encoding $false))"
git add -A
git commit -m "Demo criterio 1: error intencional en el boton Completar (ruta incorrecta)"
git push origin main
echo.
echo Listo. Revisa https://github.com/Edgar285/taskmanager-observabilidad/actions
pause
