@echo off
setlocal enabledelayedexpansion

REM Clear the log file at the start of each run
if exist nft_airdropper.log del nft_airdropper.log

REM Set up logging
set LOG_FILE=nft_airdropper.log
call :log "NFT Airdropper started"

REM Load configuration from .env file
if not exist .env (
    call :log "Error: .env file not found."
    echo .env file not found. Please create it with RPC_URL, RPC_USER, and RPC_PASS.
    pause
    exit /b 1
)

REM Improved .env parsing
for /f "usebackq tokens=1,2 delims==" %%A in (.env) do (
    set "%%A=%%B"
)

REM Verify required variables
for %%v in (RPC_URL RPC_USER RPC_PASS) do (
    if not defined %%v (
        call :log "Error: %%v not defined in .env"
        echo %%v not defined in .env file. Please add it.
        pause
        exit /b 1
    )
)

REM Test RPC connection
echo Testing RPC connection...
call :log "Testing RPC connection"
call :send_rpc_command "getblockcount"
call :check_error "Unable to connect to Evrmore node. Check your RPC settings and node status."
echo RPC connection successful. Block count: %RESULT%
call :log "RPC connection successful. Block count: %RESULT%"

:menu
cls
echo ===================================
echo        NFT Airdropper Menu
echo ===================================
echo.
echo Asset Management:
echo   1. List existing assets
echo   2. Mint unique 1-of-1 asset
echo.
echo Airdrop Operations:
echo   3. Airdrop to single address
echo   4. Airdrop to multiple addresses
echo.
echo Balance Operations:
echo   5. Check EVR balance
echo   6. Check asset balance
echo.
echo   7. Exit
echo.
echo ===================================
set /p CHOICE="Enter your choice (1-7): "

if "%CHOICE%"=="1" goto list_assets
if "%CHOICE%"=="2" goto mint_unique_asset
if "%CHOICE%"=="3" goto airdrop_single
if "%CHOICE%"=="4" goto airdrop_multiple
if "%CHOICE%"=="5" goto check_evr_balance
if "%CHOICE%"=="6" goto check_asset_balance
if "%CHOICE%"=="7" goto end
echo Invalid choice. Please try again.
pause
goto menu

:check_evr_balance
echo.
echo === Check EVR Balance ===
call :send_rpc_command "getbalance"
call :check_error "Error occurred while checking EVR balance."

set "EVR_BALANCE="
for /f "tokens=2 delims=:" %%a in ('type rpc_output.txt ^| findstr /C:"result"') do (
    for /f "tokens=1 delims=," %%b in ("%%a") do (
        set "EVR_BALANCE=%%b"
    )
)

if not defined EVR_BALANCE (
    echo Unable to retrieve EVR balance.
) else (
    echo Your EVR balance is: %EVR_BALANCE% EVR
    call :log "EVR balance checked: %EVR_BALANCE%"
)
pause
goto menu

:check_asset_balance
echo.
echo === Check Asset Balance ===
set /p ASSET_NAME="Enter the asset name: "
call :send_rpc_command "listmyassets" "%ASSET_NAME%" true
call :check_error "Error occurred while checking asset balance."

set "ASSET_BALANCE="
for /f "tokens=1,* delims=:" %%a in ('type rpc_output.txt ^| findstr /C:"balance"') do (
    for /f "tokens=1 delims=," %%c in ("%%b") do (
        set "ASSET_BALANCE=%%c"
    )
)

if not defined ASSET_BALANCE (
    echo Asset %ASSET_NAME% not found in your wallet.
) else (
    echo Your balance of %ASSET_NAME% is: %ASSET_BALANCE%
    call :log "Asset balance checked for %ASSET_NAME%: %ASSET_BALANCE%"
)
pause
goto menu

:list_assets
echo.
echo === List Existing Assets ===
set /p ASSET_FILTER="Enter asset name filter (or press Enter for all): "
if not defined ASSET_FILTER set ASSET_FILTER=*
set /p VERBOSE="Show verbose output? (y/n): "
if /i "%VERBOSE%"=="y" (
    set VERBOSE=true
) else (
    set VERBOSE=false
)
set /p COUNT="Enter maximum number of results (or press Enter for all): "
if not defined COUNT set COUNT=100
set /p START="Enter start position (or press Enter for 0): "
if not defined START set START=0
set /p CONFS="Enter minimum confirmations (or press Enter for default): "
if not defined CONFS set CONFS=1

call :log "Listing my assets with filter: %ASSET_FILTER%"
call :send_rpc_command "listmyassets" "%ASSET_FILTER%" %VERBOSE% %COUNT% %START% %CONFS%
call :check_error "Error occurred while listing my assets."

call :parse_list_assets_output
pause
goto menu

:parse_list_assets_output
set "ASSET_LIST="
for /f "tokens=*" %%a in ('type rpc_output.txt ^| findstr /i /c:"\"result\""') do (
    set "line=%%a"
    REM Clean up the line to remove unwanted characters
    set "line=!line:{=!"
    set "line=!line:}=!"
    set "line=!line:["=!"
    set "line=!line:]"=!"
    set "line=!line:"=!"
    REM Append the cleaned line to the asset list
    set "ASSET_LIST=!ASSET_LIST!!line!"
)

REM If assets were found, display them
if not defined ASSET_LIST (
    echo No assets found or unable to retrieve assets.
) else (
    echo Assets found:
    echo !ASSET_LIST!
)

REM Log the output for later review
echo !ASSET_LIST! > asset_list.txt
goto :eof


:mint_unique_asset
echo.
echo === Mint Unique 1-of-1 Asset ===
set /p ROOT_ASSET_NAME="Enter the root asset name: "
set /p UNIQUE_TAG="Enter the unique tag (e.g., 001): "
set /p IPFS_HASH="Enter the IPFS hash (optional): "
set /p TO_ADDRESS="Enter the recipient address: "
set /p CHANGE_ADDRESS="Enter the change address (optional): "

REM Confirm before proceeding
echo.
echo You are about to mint a unique asset:
echo Root Asset Name: %ROOT_ASSET_NAME%
echo Unique Tag: %UNIQUE_TAG%
echo Recipient Address: %TO_ADDRESS%
set /p CONFIRM="Are you sure you want to proceed? (y/n): "
if /i "%CONFIRM%" neq "y" goto menu

call :log "Minting unique asset: %ROOT_ASSET_NAME%#%UNIQUE_TAG%"
call :send_rpc_command "issueunique" "%ROOT_ASSET_NAME%" "[\""%UNIQUE_TAG%"\"]" "[\""%IPFS_HASH%"\"]" "%TO_ADDRESS%" "%CHANGE_ADDRESS%"
call :check_error "Error occurred while minting unique asset."

call :log "Mint result: %RESULT%"
echo Unique asset minted successfully. TXID: %RESULT%
echo %RESULT%, %ROOT_ASSET_NAME%, %TO_ADDRESS%, %DATE% %TIME% >> transactions.txt
pause
goto menu


:airdrop_single
echo.
echo === Airdrop to Single Address ===
set /p ASSET_NAME="Enter the asset name: "
set /p AMOUNT="Enter the asset amount: "
set /p TO_ADDRESS="Enter the recipient address: "
set /p MESSAGE="Enter the message (optional): "

REM Confirm before proceeding
echo.
echo You are about to airdrop:
echo Asset: %ASSET_NAME%
echo Amount: %AMOUNT%
echo Recipient Address: %TO_ADDRESS%
set /p CONFIRM="Are you sure you want to proceed? (y/n): "
if /i "%CONFIRM%" neq "y" goto menu

call :log "Sending %AMOUNT% %ASSET_NAME% to %TO_ADDRESS%"
call :send_rpc_command "transfer" "%ASSET_NAME%" "%AMOUNT%" "%TO_ADDRESS%" "%MESSAGE%" "0"
call :check_error "Error occurred while sending asset."

call :parse_rpc_output
if not defined TXID (
    echo Error: TXID not found in the output. Check %LOG_FILE%.
) else (
    echo Transfer successful. TXID: %TXID%
    echo %TXID%, %ASSET_NAME%, %TO_ADDRESS%, %DATE% %TIME% >> transactions.txt
    call :log "Airdrop to single address completed. TXID: %TXID%"
)
pause
goto menu


:airdrop_multiple
echo.
echo === Airdrop to Multiple Addresses ===
if not exist addresses.txt (
    echo Error: addresses.txt file not found.
    pause
    goto menu
)

set /p ASSET_NAME="Enter the asset name to airdrop: "
set /p AMOUNT="Enter the amount to send to each address: "

REM Confirm before proceeding
echo.
echo You are about to airdrop %AMOUNT% of %ASSET_NAME% to multiple addresses.
echo Addresses file: addresses.txt
set /p CONFIRM="Are you sure you want to proceed? (y/n): "
if /i "%CONFIRM%" neq "y" goto menu

call :log "Starting airdrop to multiple addresses"
for /f "tokens=*" %%a in (addresses.txt) do (
    set TO_ADDRESS=%%a
    call :log "Sending %AMOUNT% %ASSET_NAME% to !TO_ADDRESS!"
    call :send_rpc_command "transfer" "%ASSET_NAME%" "%AMOUNT%" "!TO_ADDRESS!"
    if !ERRORLEVEL! neq 0 (
        call :log "Error occurred while sending asset to !TO_ADDRESS!"
    ) else (
        call :parse_rpc_output
        if not defined TXID (
            call :log "Error: TXID not found for !TO_ADDRESS!"
        ) else (
            echo Transfer successful. TXID: !TXID!
            echo !TXID!, %ASSET_NAME%, !TO_ADDRESS!, %DATE% %TIME% >> transactions.txt
            call :log "Airdrop to !TO_ADDRESS! completed. TXID: !TXID!"
        )
    )
)
call :log "Finished airdrop to multiple addresses"
echo Airdrop completed. Check transactions.txt for details.
pause
goto menu


:send_rpc_command
setlocal
set "params="
set "method=%~1"
shift

:build_params
if "%~1"=="" goto execute_command
if defined params (
    set "params=!params!,"
)
if "%~1"=="" (
    set "params=!params!null"
) else if "%~1"=="true" (
    set "params=!params!true"
) else if "%~1"=="false" (
    set "params=!params!false"
) else if "%~1"=="0" (
    set "params=!params!0"
) else if 1%~1 EQU +1%~1 (
    set "params=!params!%~1"
) else (
    set "params=!params!\"%~1\""
)
shift
goto build_params

:execute_command
set "json={\"jsonrpc\": \"1.0\", \"id\":\"curltest\", \"method\": \"%method%\", \"params\": [%params%]}"
call :log "Sending RPC command: %method%"
call :log "Full JSON request: %json%"
curl --max-time 30 -s -u %RPC_USER%:%RPC_PASS% -d "%json%" -H "content-type: text/plain;" %RPC_URL% > rpc_output.txt 2>> %LOG_FILE%
call :log "Curl command completed with exit code: %ERRORLEVEL%"
call :log "Full RPC response:"
type rpc_output.txt >> %LOG_FILE%

if %ERRORLEVEL% neq 0 (
    call :log "Error occurred while executing RPC command: %method%"
    set RESULT=error:CurlFailed
    echo %RESULT% > asset_list.txt
    exit /b 1
)

set "RESULT="
for /f "usebackq delims=" %%a in (`type rpc_output.txt ^| findstr /C:"\"result\""`) do (
    set "line=%%a"
    set "line=!line:~10!"
    set "line=!line:~0,-1!"
    set "RESULT=!line!"
)

if "%method%"=="listmyassets" (
    if "!RESULT!"=="" (
        echo No assets found.
    ) else (
        echo !RESULT! > asset_list.txt
        for /f "tokens=1,* delims=:" %%a in (asset_list.txt) do (
            set "asset_name=%%a"
            set "asset_name=!asset_name:{=!"
            set "asset_name=!asset_name:"=!"
            for /f "tokens=1 delims=," %%c in ("%%b") do (
                echo Asset: !asset_name!, Balance: %%c
            )
        )
    )
)
call :log "RPC command result: !RESULT!"
if "!RESULT:~0,5!"=="error" (
    exit /b 1
) else (
    endlocal & set "RESULT=!RESULT!"
    exit /b 0
)

:parse_rpc_output
for /f "tokens=2 delims=[]," %%a in ('findstr /i /c:"\"result\"" rpc_output.txt') do set TXID=%%~a
goto :eof

:check_error
if %ERRORLEVEL% neq 0 (
    call :log "Error: %~1"
    echo Error: %~1
    pause
    exit /b 1
)
goto :eof

:log
echo [%date% %time%] %~1 >> %LOG_FILE%
goto :eof

:end
call :log "NFT Airdropper ended"
exit /b 0
