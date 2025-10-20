@echo off
echo ========================================
echo  Redeploying Prediction Market Contract
echo ========================================
echo.
echo Step 1: Compiling contract...
call npx hardhat compile
if %errorlevel% neq 0 (
    echo ERROR: Compilation failed!
    pause
    exit /b 1
)
echo.
echo Step 2: Deploying to localhost...
call npx hardhat run scripts/deploy.js --network localhost
if %errorlevel% neq 0 (
    echo ERROR: Deployment failed!
    pause
    exit /b 1
)
echo.
echo ========================================
echo  SUCCESS! Contract deployed
echo ========================================
echo.
echo NEXT STEPS:
echo 1. Clear MetaMask: Settings ^> Advanced ^> Clear activity tab data
echo 2. Hard refresh browser: Ctrl + Shift + R
echo.
pause
