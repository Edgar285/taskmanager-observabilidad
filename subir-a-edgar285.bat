@echo off
REM Sube el proyecto al repositorio de la cuenta Edgar285
cd /d "%~dp0"
REM El usuario en la URL hace que Git pida (o use) la sesion de Edgar285 y no la de otra cuenta
git remote set-url origin https://Edgar285@github.com/Edgar285/taskmanager-observabilidad.git 2>nul || git remote add origin https://Edgar285@github.com/Edgar285/taskmanager-observabilidad.git
git add -A
git commit -m "Proyecto final: frontend, Playwright, OpenTelemetry y OpenObserve" 2>nul
git branch -M main
git push -u origin main
echo.
echo Listo. Revisa la pestana Actions de https://github.com/Edgar285/taskmanager-observabilidad
pause
