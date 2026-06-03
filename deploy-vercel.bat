@echo off
echo ============================================
echo  Deploiement Vercel - Fiche Client Proactifs
echo ============================================
echo.
node "%~dp0deploy-vercel.js" > "%~dp0deploy-log.txt" 2>&1
echo Script termine. Voir deploy-log.txt pour le resultat.
echo.
pause
