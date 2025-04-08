# PowerShell script for pushing changes to the NeuralLog/specs repository

Write-Host "Pushing changes to NeuralLog/specs repository..." -ForegroundColor Cyan

# Add all changes
Write-Host "Adding all changes..." -ForegroundColor Green
git add .

# Commit changes
$commitMessage = Read-Host -Prompt "Enter commit message"
Write-Host "Committing changes..." -ForegroundColor Green
git commit -m "$commitMessage"

# Push to GitHub
Write-Host "Pushing to GitHub..." -ForegroundColor Green
git push origin master

Write-Host "Done!" -ForegroundColor Cyan
