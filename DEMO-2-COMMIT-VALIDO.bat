@echo off
REM Criterio 2: commit valido que corrige el error y vuelve a desplegar
cd /d "%~dp0"
powershell -NoProfile -Command "$p='public\app.js'; $t=[IO.File]::ReadAllText($p); if(-not $t.Contains('/completado`')){Write-Host 'El cambio ya estaba aplicado'; exit 0}; $t=$t.Replace('/completado`','/completar`'); [IO.File]::WriteAllText($p,$t,(New-Object Text.UTF8Encoding $false))"
git add -A
git commit -m "Demo criterio 2: corrige la ruta del boton Completar"
git push origin main
echo.
echo Listo. Revisa https://github.com/Edgar285/taskmanager-observabilidad/actions
pause
