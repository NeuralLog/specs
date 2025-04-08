@echo off
echo Pushing changes to NeuralLog/specs repository...

echo Adding all changes...
git add .

echo Committing changes...
set /p commit_message="Enter commit message: "
git commit -m "%commit_message%"

echo Pushing to GitHub...
git push origin master

echo Done!
