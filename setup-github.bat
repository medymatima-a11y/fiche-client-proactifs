@echo off
echo ============================================
echo  Setup GitHub - CRM Proactifs (1 seule fois)
echo ============================================
echo.

cd /d "%~dp0"

REM Supprimer les locks git si existants
if exist ".git\config.lock" del ".git\config.lock"
if exist ".git\index.lock" del ".git\index.lock"

REM Init git et config
git init
git config user.email "medymatima@gmail.com"
git config user.name "medymatima-a11y"
git branch -M main

REM Ajouter le remote GitHub
git remote remove origin 2>nul
git remote add origin https://github.com/medymatima-a11y/fiche-client-proactifs.git

REM Ajouter tous les fichiers (sauf ceux dans .gitignore)
git add .

REM Premier commit
git commit -m "Initial commit - fiche client Proactifs"

REM Pousser vers GitHub
echo.
echo Connexion a GitHub...
echo (Entre ton token GitHub quand demande - le mot de passe ne fonctionne plus)
echo.
git push -u origin main

echo.
echo ============================================
echo  Termine ! Verifie :
echo  https://github.com/medymatima-a11y/fiche-client-proactifs
echo ============================================
echo.
pause
