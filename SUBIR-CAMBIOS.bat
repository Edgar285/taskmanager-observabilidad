@echo off
REM Sube a GitHub (cuenta Edgar285) los cambios que Claude dejo en esta carpeta
cd /d "%~dp0"
if exist ci\main.yml (
  if not exist .github\workflows mkdir .github\workflows
  move /Y ci\main.yml .github\workflows\main.yml >nul
  rmdir ci 2>nul
)
git add -A
if "%~1"=="" (git commit -m "Actualizacion del proyecto") else (git commit -m "%~1")
git push origin main
echo.
echo Listo. Revisa https://github.com/Edgar285/taskmanager-observabilidad/actions
pause
