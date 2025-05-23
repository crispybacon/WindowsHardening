# Windows11_StandAlone_MAC3_Public_Profile.ps1
# Windows 11 STIG Hardening Script - Standalone Version
# Combines all CAT1, CAT2, CAT3 findings and SANS hardening settings

# Load configuration from config.json
$configPath = Join-Path $PSScriptRoot "config.json"
if (Test-Path $configPath) {
    $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json
    $systemLogSize = $config.EventLogs.SystemLogSize
} else {
    # Default value if config.json is not found
    $systemLogSize = 32768
    Write-Host "Warning: config.json not found, using default System log size of 32768 KB" -ForegroundColor Yellow
}

# Check for administrative privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "This script requires administrative privileges. Please run as administrator." -ForegroundColor Red
    exit 1
}

Write-Host "Starting Windows 11 STIG Hardening Script..." -ForegroundColor Cyan

#region Account Renaming
# V-253435 and V-253436
Write-Host "Renaming built-in accounts..." -ForegroundColor Green
try {
    Rename-LocalUser -Name Administrator -NewName $config.AccountNames.AdminAccountName -ErrorAction SilentlyContinue
    Rename-LocalUser -Name Guest -NewName $config.AccountNames.GuestAccountName -ErrorAction SilentlyContinue
} catch {
    Write-Host "Account renaming failed. Accounts may already be renamed." -ForegroundColor Yellow
}
#endregion

#region CAT1 Findings
Write-Host "`n=== Addressing CAT1 Findings ===" -ForegroundColor Magenta

# V-253260 - Configure BitLocker to require PIN for pre-boot authentication
Write-Host "Configuring BitLocker to require PIN for pre-boot authentication (V-253260)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\FVE" /v UseAdvancedStartup /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\FVE" /v UseTPMPIN /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\FVE" /v UseTPMKeyPIN /t REG_DWORD /d 2 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\FVE" /v UseTPM /t REG_DWORD /d 2 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\FVE" /v MinimumPIN /t REG_DWORD /d $config.BitLocker.MinimumPINLength /f

# V-253386 - Turn off Autoplay for non-volume devices
Write-Host "Turning off Autoplay for non-volume devices (V-253386)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoAutoplayfornonVolume /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v NoAutoplayfornonVolume /t REG_DWORD /d 1 /f

# V-253387 - Configure default autorun behavior to prevent autorun commands
Write-Host "Configuring default autorun behavior to prevent autorun commands (V-253387)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoAutorun /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoDriveTypeAutoRun /t REG_DWORD /d 255 /f

# V-253283 - Set Data Execution Prevention (DEP)
Write-Host "Setting Data Execution Prevention (DEP) (V-253283)..." -ForegroundColor Green
BCDEDIT /set "{current}" nx AlwaysON

# V-253284 - Disable Exception Chain Validation
Write-Host "Disabling Exception Chain Validation (V-253284)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v DisableExceptionChainValidation /t REG_DWORD /d 0 /f
#endregion

#region CAT2 Findings - Part 1
Write-Host "`n=== Addressing CAT2 Findings - Part 1 ===" -ForegroundColor Magenta

# V-253285 and V-253286 - Disable PowerShell V2 and SMB1Protocol
Write-Host "Disabling PowerShell V2 and SMB1Protocol (V-253285, V-253286)..." -ForegroundColor Green
Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root -NoRestart
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart

# V-253289 - Disable Secondary Logon Service
Write-Host "Disabling Secondary Logon Service (V-253289)..." -ForegroundColor Green
Set-Service -Name seclogon -StartupType Disabled

# V-253273 - Accounts must be configured to require password expiration
Write-Host "Configuring password expiration (V-253273)..." -ForegroundColor Green
Get-LocalUser | ForEach-Object { Set-LocalUser -Name $_.Name -PasswordNeverExpires $false }

# V-253297 - V-253303 - Set various account lockout and password policies
Write-Host "Setting account lockout and password policies..." -ForegroundColor Green
# Store values in variables first
$lockoutDuration = $config.AccountPolicies.LockoutDuration
$lockoutThreshold = $config.AccountPolicies.LockoutThreshold
$lockoutWindow = $config.AccountPolicies.LockoutWindow
$uniquePw = $config.AccountPolicies.UniquePasswordHistory
$maxPwAge = $config.AccountPolicies.MaxPasswordAge
$minPwAge = $config.AccountPolicies.MinPasswordAge
$minPwLen = $config.AccountPolicies.MinPasswordLength

# Apply account policies
net accounts /lockoutduration:$lockoutDuration
net accounts /lockoutthreshold:$lockoutThreshold
net accounts /lockoutwindow:$lockoutWindow
net accounts /uniquepw:$uniquePw
net accounts /maxpwage:$maxPwAge
net accounts /minpwage:$minPwAge
net accounts /minpwlen:$minPwLen


# V-253304 - Configure Security Policy for Password Complexity
Write-Host "Configuring password complexity (V-253304)..." -ForegroundColor Green
secedit /export /cfg c:\secpol.cfg
(Get-Content C:\secpol.cfg).replace("PasswordComplexity = 0", "PasswordComplexity = 1") | Out-File C:\secpol.cfg
secedit /configure /db c:\windows\security\local.sdb /cfg c:\secpol.cfg /areas SECURITYPOLICY
Remove-Item -Force c:\secpol.cfg -Confirm:$false

# V-253305 - V-253336 and V-257770 - Enable audit policies
# Fix for audit policies in Windows 11 STIG Hardening Script
# This script addresses the error with audit policy configuration

Write-Host "Enabling audit policies..." -ForegroundColor Green

# Define audit subcategories to enable
$auditSubcategories = @(
    "Credential Validation",
    "Security Group Management",
    "User Account Management",
    "Process Creation",
    "Account Lockout",
    "File Share",
    "Other Object Access Events",
    "Audit Policy Change",
    "Authentication Policy Change",
    "Authorization Policy Change",
    "Sensitive Privilege Use",
    "IPsec Driver",
    "Security System Extension",
    "Other Policy Change Events",
    "Other Logon/Logoff Events",
    "Detailed File Share",
    "MPSSVC Rule-Level Policy Change",
    "Group Membership"
)

# Enable each audit subcategory with proper syntax
foreach ($subcategory in $auditSubcategories) {
    try {
        Write-Host "Enabling audit policy for: $subcategory" -ForegroundColor Cyan
        # Use double quotes around the subcategory name and ensure proper spacing
        auditpol /set /subcategory:"$subcategory" /failure:enable /success:enable
    } catch {
        Write-Host "Could not set audit policy for: $subcategory" -ForegroundColor Yellow
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

# Handle PNP Activity and Removable Storage separately with quotes
try {
    Write-Host "Enabling audit policy for: Plug and Play Events" -ForegroundColor Cyan
    auditpol /set /subcategory:"Plug and Play Events" /failure:enable /success:enable
    
    Write-Host "Enabling audit policy for: Removable Storage" -ForegroundColor Cyan
    auditpol /set /subcategory:"Removable Storage" /failure:enable /success:enable
} catch {
    Write-Host "Could not set audit policy for PNP or Removable Storage" -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor Red
}

Write-Host "Audit policy configuration completed." -ForegroundColor Green
Write-Host "Note: This script must be run as administrator to modify audit policies." -ForegroundColor Yellow

# V-253337 - V-253339 - Set MaxSize for Event Log Applications
Write-Host "Setting event log sizes..." -ForegroundColor Green
limit-eventlog -LogName Application -MaximumSize ($config.EventLogs.ApplicationLogSize * 1KB)
limit-eventlog -LogName Security -MaximumSize ($config.EventLogs.SecurityLogSize * 1KB)
limit-eventlog -LogName System -MaximumSize ($config.EventLogs.SystemLogSize * 1KB)

# V-253338
# Fix for V-253338 - Security event log size
Write-Host "Setting Security event log size registry key to 1024000 KB..." -ForegroundColor Green

# Create the registry path if it doesn't exist
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\Security"
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}

# Set the MaxSize registry value to 1024000 KB
Set-ItemProperty -Path $regPath -Name "MaxSize" -Value 1024000 -Type DWord

# Also set using limit-eventlog for immediate effect
limit-eventlog -LogName Security -MaximumSize 1024000KB
Write-Host "Security event log size registry key set to 1024000 KB." -ForegroundColor Green

# V-253339
Write-Host "Setting System event log size registry key..." -ForegroundColor Green

# Create the registry path if it doesn't exist
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\System"
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
    Write-Host "Created registry path: $regPath" -ForegroundColor Cyan
}

# Set the MaxSize registry value to the configured value
Set-ItemProperty -Path $regPath -Name "MaxSize" -Value $systemLogSize -Type DWord
Write-Host "Set System event log MaxSize registry value to $systemLogSize KB" -ForegroundColor Green

# Also set using limit-eventlog for immediate effect
limit-eventlog -LogName System -MaximumSize ($systemLogSize * 1KB)
Write-Host "Set System event log size to $systemLogSize KB using limit-eventlog" -ForegroundColor Green

Write-Host "System event log registry configuration completed successfully." -ForegroundColor Green

#endregion
#region CAT2 Findings - Part 2
Write-Host "`n=== Addressing CAT2 Findings - Part 2 ===" -ForegroundColor Magenta

# V-253351 - Cover or disable built-in camera when not in use
Write-Host "Disabling camera (V-253351)..." -ForegroundColor Green
# Disable camera globally
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Camera" /v "AllowCamera" /t REG_DWORD /d 0 /f
# Disable camera access from lock screen
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Personalization" /v "NoLockScreenCamera" /t REG_DWORD /d 1 /f

# V-253352 - Disable display of slide shows on the lock screen
Write-Host "Disabling lock screen slide shows (V-253352)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Personalization" /v NoLockScreenSlideshow /t REG_DWORD /d 1 /f

# V-253380 - Prompt for password on resume from sleep (on battery)
Write-Host "Configuring password prompt on resume from sleep (on battery) (V-253380)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Power\PowerSettings\0e796bdb-100d-47d6-a2d5-f7d2daa51f51" /v DCSettingIndex /t REG_DWORD /d 1 /f

# V-253381 - Prompt for password on resume from sleep (plugged in)
Write-Host "Configuring password prompt on resume from sleep (plugged in) (V-253381)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Power\PowerSettings\0e796bdb-100d-47d6-a2d5-f7d2daa51f51" /v ACSettingIndex /t REG_DWORD /d 1 /f

# V-253414 - Enable PowerShell script block logging
Write-Host "Enabling PowerShell script block logging (V-253414)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" /v EnableScriptBlockLogging /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" /v EnableTranscripting /t REG_DWORD /d 1 /f

# V-253444 - Set machine inactivity limit to 15 minutes
Write-Host "Setting machine inactivity limit to 15 minutes (V-253444)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v InactivityTimeoutSecs /t REG_DWORD /d 900 /f

# V-253445 - Configure required legal notice
Write-Host "Configuring legal notice (V-253445)..." -ForegroundColor Green

# Get values directly from the config object
$legalNoticeCaption = $config.LegalNotice.Caption
$legalNoticeText = $config.LegalNotice.Text

# Debug output to verify values
Write-Host "Setting legal notice caption: $legalNoticeCaption" -ForegroundColor Cyan
Write-Host "Setting legal notice text: $legalNoticeText" -ForegroundColor Cyan

# Use PowerShell's Set-ItemProperty instead of reg add for better handling of special characters
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
Set-ItemProperty -Path $regPath -Name "legalnoticecaption" -Value $legalNoticeCaption -Type String
Set-ItemProperty -Path $regPath -Name "legalnoticetext" -Value $legalNoticeText -Type String

# Verify the values were set correctly
$verifyCaption = (Get-ItemProperty -Path $regPath -Name "legalnoticecaption").legalnoticecaption
$verifyText = (Get-ItemProperty -Path $regPath -Name "legalnoticetext").legalnoticetext
Write-Host "Verified legal notice caption: $verifyCaption" -ForegroundColor Green
Write-Host "Verified legal notice text: $verifyText" -ForegroundColor Green

# V-253460 - Configure Kerberos encryption types
Write-Host "Configuring Kerberos encryption types (V-253460)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Kerberos\Parameters" /v SupportedEncryptionTypes /t REG_DWORD /d 0x7ffffff8 /f

# V-268317 - Disable Copilot in Windows
Write-Host "Disabling Copilot in Windows (V-268317)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v "TurnOffWindowsCopilot" /t REG_DWORD /d 1 /f
#endregion

#region Network and Security Settings
Write-Host "`n=== Configuring Network and Security Settings ===" -ForegroundColor Magenta

# V-253353 - IPv6 Source Routing
Write-Host "Configuring IPv6 Source Routing (V-253353)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" /v DisableIPSourceRouting /t REG_DWORD /d 2 /f

# V-253354 - IPv4 Source Routing
Write-Host "Configuring IPv4 Source Routing (V-253354)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\Tcpip\Parameters" /v DisableIPSourceRouting /t REG_DWORD /d 2 /f

# V-253355 - ICMP Redirect
Write-Host "Configuring ICMP Redirect (V-253355)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v EnableICMPRedirect /t REG_DWORD /d 0 /f

# V-253356 - NetBIOS Name Release
Write-Host "Configuring NetBIOS Name Release (V-253356)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NetBT\Parameters" /v NoNameReleaseOnDemand /t REG_DWORD /d 1 /f

# V-253358 - WDigest Authentication
Write-Host "Configuring WDigest Authentication (V-253358)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\Wdigest" /v UseLogonCredential /t REG_DWORD /d 0 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Classes\batfile\shell\runasuser" /v SuppressionPolicy /t REG_DWORD /d 4096 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Classes\cmdfile\shell\runasuser" /v SuppressionPolicy /t REG_DWORD /d 4096 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Classes\exefile\shell\runasuser" /v SuppressionPolicy /t REG_DWORD /d 4096 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Classes\mscfile\shell\runasuser" /v SuppressionPolicy /t REG_DWORD /d 4096 /f

# V-253360 - Insecure Guest Auth
Write-Host "Configuring Insecure Guest Auth (V-253360)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\LanmanWorkstation" /v AllowInsecureGuestAuth /t REG_DWORD /d 0 /f

# V-253361 - Network Sharing UI
Write-Host "Configuring Network Sharing UI (V-253361)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Network Connections" /v NC_ShowSharedAccessUI /t REG_DWORD /d 0 /f

# V-253365 - Block Non-Domain Networks
Write-Host "Configuring Block Non-Domain Networks (V-253365)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WcmSvc\GroupPolicy" /v fBlockNonDomain /t REG_DWORD /d 1 /f

# V-253366 - WiFi Network Manager
Write-Host "Configuring WiFi Network Manager (V-253366)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config" /v AutoConnectAllowedOEM /t REG_DWORD /d 0 /f

# V-253367 - Process Creation Audit
Write-Host "Configuring Process Creation Audit (V-253367)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" /v ProcessCreationIncludeCmdLine_Enabled /t REG_DWORD /d 1 /f

# V-253368 - Credential Delegation
Write-Host "Configuring Credential Delegation (V-253368)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation" /v AllowProtectedCreds /t REG_DWORD /d 1 /f
#endregion
#region Additional Security Settings
Write-Host "`n=== Configuring Additional Security Settings ===" -ForegroundColor Magenta

# V-253372 - Early Launch Driver Policy
Write-Host "Configuring Early Launch Driver Policy (V-253372)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Policies\EarlyLaunch" /v DriverLoadPolicy /t REG_DWORD /d 8 /f

# Fix for V-253337 - Application event log size
Write-Host "Setting Application event log size registry key..." -ForegroundColor Green

# Create the registry path if it doesn't exist
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\Application"
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}

# Set the MaxSize registry value to 32768 KB
Set-ItemProperty -Path $regPath -Name "MaxSize" -Value 32768 -Type DWord

# Also set using limit-eventlog for immediate effect
limit-eventlog -LogName Application -MaximumSize 32768KB

# V-253374 - Web PnP Download
Write-Host "Configuring Web PnP Download (V-253374)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Printers" /v DisableWebPnPDownload /t REG_DWORD /d 1 /f

# V-253375 - Web Services
Write-Host "Configuring Web Services (V-253375)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoWebServices /t REG_DWORD /d 1 /f

# V-253376 - HTTP Printing
Write-Host "Configuring HTTP Printing (V-253376)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Printers" /v DisableHTTPPrinting /t REG_DWORD /d 1 /f

# V-253378 - Network Selection UI
Write-Host "Configuring Network Selection UI (V-253378)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System" /v DontDisplayNetworkSelectionUI /t REG_DWORD /d 1 /f

# V-253382 - Remote Assistance
Write-Host "Configuring Remote Assistance (V-253382)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v fAllowToGetHelp /t REG_DWORD /d 0 /f

# V-253383 - RPC Restrictions
Write-Host "Configuring RPC Restrictions (V-253383)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Rpc" /v RestrictRemoteClients /t REG_DWORD /d 1 /f

# V-253384 - Microsoft Accounts
Write-Host "Configuring Microsoft Accounts (V-253384)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v MSAOptional /t REG_DWORD /d 1 /f

# V-253385 - App Inventory
Write-Host "Configuring App Inventory (V-253385)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\AppCompat" /v DisableInventory /t REG_DWORD /d 1 /f

# V-253389 - Facial Features Anti-Spoofing
Write-Host "Configuring Facial Features Anti-Spoofing (V-253389)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Biometrics\FacialFeatures" /v EnhancedAntiSpoofing /t REG_DWORD /d 1 /f

# V-253390 - Windows Consumer Features
Write-Host "Configuring Windows Consumer Features (V-253390)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f

# V-253391 - Credential UI
Write-Host "Configuring Credential UI (V-253391)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\CredUI" /v EnumerateAdministrators /t REG_DWORD /d 0 /f

# V-253393 - Telemetry
Write-Host "Configuring Telemetry (V-253393)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f

# V-253394 - Delivery Optimization
Write-Host "Configuring Delivery Optimization (V-253394)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" /v DODownloadMode /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\DeliveryOptimization" /v DODownloadMode /t REG_DWORD /d 1 /f

# V-253395 - SmartScreen
Write-Host "Configuring SmartScreen (V-253395)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\System" /v EnableSmartScreen /t REG_DWORD /d 1 /f

# V-253399 - Game DVR
Write-Host "Configuring Game DVR (V-253399)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR /t REG_DWORD /d 0 /f

# V-253401 - PIN Complexity
Write-Host "Configuring PIN Complexity (V-253401)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\PassportForWork\PINComplexity" /v MinimumPINLength /t REG_DWORD /d 6 /f

# V-253402 - Terminal Services Password Saving
Write-Host "Configuring Terminal Services Password Saving (V-253402)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v DisablePasswordSaving /t REG_DWORD /d 1 /f

# V-253403 - Terminal Services Client Data Redirection
Write-Host "Configuring Terminal Services Client Data Redirection (V-253403)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows NT\Terminal Services" /v fDisableCdm /t REG_DWORD /d 1 /f

# V-253404 - Terminal Services Password Prompt
Write-Host "Configuring Terminal Services Password Prompt (V-253404)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v fPromptForPassword /t REG_DWORD /d 1 /f

# V-253405 - Terminal Services RPC Encryption
Write-Host "Configuring Terminal Services RPC Encryption (V-253405)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows NT\Terminal Services" /v fEncryptRPCTraffic /t REG_DWORD /d 1 /f

# V-253406 - Terminal Services Encryption Level
Write-Host "Configuring Terminal Services Encryption Level (V-253406)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows NT\Terminal Services" /v MinEncryptionLevel /t REG_DWORD /d 3 /f

# V-253407 - IE Feeds
Write-Host "Configuring IE Feeds (V-253407)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Internet Explorer\Feeds" /v DisableEnclosureDownload /t REG_DWORD /d 1 /f

# V-253409 - Windows Search
Write-Host "Configuring Windows Search (V-253409)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowIndexingEncryptedStoresOrItems /t REG_DWORD /d 0 /f

# V-253410 - Windows Installer User Control
Write-Host "Configuring Windows Installer User Control (V-253410)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Installer" /v EnableUserControl /t REG_DWORD /d 0 /f

# V-253411 - Windows Installer Elevated Installs
Write-Host "Configuring Windows Installer Elevated Installs (V-253411)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Installer" /v AlwaysInstallElevated /t REG_DWORD /d 0 /f

# V-253413 - Automatic Restart Sign-On
Write-Host "Configuring Automatic Restart Sign-On (V-253413)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableAutomaticRestartSignOn /t REG_DWORD /d 1 /f
#endregion
#region WinRM and Advanced Security Settings
Write-Host "`n=== Configuring WinRM and Advanced Security Settings ===" -ForegroundColor Magenta

# V-253416 - WinRM Client Basic Auth
Write-Host "Configuring WinRM Client Basic Auth (V-253416)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\WinRM\Client" /v AllowBasic /t REG_DWORD /d 0 /f

# V-253417 - WinRM Client Unencrypted Traffic
Write-Host "Configuring WinRM Client Unencrypted Traffic (V-253417)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\WinRM\Client" /v AllowUnencryptedTraffic /t REG_DWORD /d 0 /f

# V-253418 - WinRM Service Basic Auth
Write-Host "Configuring WinRM Service Basic Auth (V-253418)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" /v AllowBasic /t REG_DWORD /d 0 /f

# V-253419 - WinRM Service Unencrypted Traffic
Write-Host "Configuring WinRM Service Unencrypted Traffic (V-253419)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\WinRM\Service" /v AllowUnencryptedTraffic /t REG_DWORD /d 0 /f

# V-253420 - WinRM Service RunAs
Write-Host "Configuring WinRM Service RunAs (V-253420)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\WinRM\Service" /v DisableRunAs /t REG_DWORD /d 1 /f

# V-253421 - WinRM Client Digest
Write-Host "Configuring WinRM Client Digest (V-253421)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\WinRM\Client" /v AllowDigest /t REG_DWORD /d 0 /f

# V-253422 - App Voice Activation
Write-Host "Configuring App Voice Activation (V-253422)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsActivateWithVoice /t REG_DWORD /d 2 /f

# V-253423 - Domain PIN Logon
Write-Host "Configuring Domain PIN Logon (V-253423)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\System" /v AllowDomainPINLogon /t REG_DWORD /d 0 /f

# V-253424 - Windows Ink Workspace
Write-Host "Configuring Windows Ink Workspace (V-253424)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\WindowsInkWorkspace" /v AllowWindowsInkWorkspace /t REG_DWORD /d 1 /f

# V-253426 - Kernel DMA Protection
Write-Host "Configuring Kernel DMA Protection (V-253426)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Kernel DMA Protection" /v DeviceEnumerationPolicy /t REG_DWORD /d 0 /f

# V-253437 - Legacy Audit Policy
Write-Host "Configuring Legacy Audit Policy (V-253437)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa" /v SCENoApplyLegacyAuditPolicy /t REG_DWORD /d 1 /f

# V-253448 - Smart Card Removal Option
Write-Host "Configuring Smart Card Removal Option (V-253448)..." -ForegroundColor Green
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v SCRemoveOption /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v SCRemoveOption /t REG_SZ /d 1 /f

# V-253449 - LanMan Workstation Security Signature
Write-Host "Configuring LanMan Workstation Security Signature (V-253449)..." -ForegroundColor Green
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" -Name "RequireSecuritySignature" -Value 1

# V-253451 - LanMan Server Security Signature
Write-Host "Configuring LanMan Server Security Signature (V-253451)..." -ForegroundColor Green
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters" -Name RequireSecuritySignature -Value 1

# V-253454 - Restrict Anonymous
Write-Host "Configuring Restrict Anonymous (V-253454)..." -ForegroundColor Green
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\" -Name restrictanonymous -Value 1

# V-253457 - Restrict Remote SAM
Write-Host "Configuring Restrict Remote SAM (V-253457)..." -ForegroundColor Green
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RestrictRemoteSAM" -Value "O:BAG:BAD:(A;;RC;;;BA)"

# V-253458 - MSV1_0 Null Session Fallback
Write-Host "Configuring MSV1_0 Null Session Fallback (V-253458)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0" /v allownullsessionfallback /t REG_DWORD /d 0 /f

# V-253459 - PKU2U Online ID
Write-Host "Configuring PKU2U Online ID (V-253459)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\LSA\pku2u" /v AllowOnlineID /t REG_DWORD /d 0 /f

# V-253462 - LM Compatibility Level
Write-Host "Configuring LM Compatibility Level (V-253462)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa" /v LmCompatibilityLevel /t REG_DWORD /d 5 /f

# V-253464 - NTLM Min Client Sec
Write-Host "Configuring NTLM Min Client Sec (V-253464)..." -ForegroundColor Green
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0" -Name NTLMMinClientSec -Value 0x20080000

# V-253465 - NTLM Min Server Sec
Write-Host "Configuring NTLM Min Server Sec (V-253465)..." -ForegroundColor Green
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0" -Name NTLMMinServerSec -Value 0x20080000

# V-253466 - FIPS Algorithm Policy
Write-Host "Configuring FIPS Algorithm Policy (V-253466)..." -ForegroundColor Green
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\FIPSAlgorithmPolicy" -Name Enabled -Value 1

# V-253468 - Filter Administrator Token
Write-Host "Configuring Filter Administrator Token (V-253468)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v FilterAdministratorToken /t REG_DWORD /d 1 /f

# V-253469 - Admin Consent Prompt Behavior
Write-Host "Configuring Admin Consent Prompt Behavior (V-253469)..." -ForegroundColor Green
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name ConsentPromptBehaviorAdmin -Value 2

# V-253471 - User Consent Prompt Behavior
Write-Host "Configuring User Consent Prompt Behavior (V-253471)..." -ForegroundColor Green
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name ConsentPromptBehaviorUser -Value 0
#endregion
#region User Rights Assignments
Write-Host "`n=== Configuring User Rights Assignments ===" -ForegroundColor Magenta

# Create a temporary security policy file
$infFile = "$env:TEMP\SecurityPolicy.inf"
$backupFile = "$env:TEMP\SecurityPolicyBackup.inf"

# Export current security policy
Write-Host "Exporting current security policy..." -ForegroundColor Green
secedit /export /cfg $infFile

# Backup the original policy
Copy-Item $infFile $backupFile

# Define groups to remove from network logon right
$groupsToRemove = @("Everyone", "Users", "Remote Desktop Users", "Backup Operators")

# Read the policy file
$content = Get-Content $infFile

# V-253480 - "Access this computer from the network" user right

Write-Host "Starting fix for V-253480..." -ForegroundColor Cyan
Write-Host "Configuring 'Access this computer from the network' user right to only include Administrators and Remote Desktop Users..." -ForegroundColor Green

# Create a temporary security policy file
$infFile = "$env:TEMP\SecurityPolicy.inf"
$backupFile = "$env:TEMP\SecurityPolicyBackup.inf"

# Export current security policy
Write-Host "Exporting current security policy..." -ForegroundColor Green
secedit /export /cfg $infFile

# Backup the original policy
Copy-Item $infFile $backupFile

# Read the policy file
$content = Get-Content $infFile

# Find the line containing SeNetworkLogonRight
$networkLogonLine = $content | Where-Object { $_ -match "SeNetworkLogonRight" }

Write-Host "Current SeNetworkLogonRight setting: $networkLogonLine" -ForegroundColor Yellow

# Replace the line with the correct configuration
# We want to ensure only Administrators and Remote Desktop Users have this right
$newNetworkLogonLine = "SeNetworkLogonRight = *S-1-5-32-544,*S-1-5-32-555"

# Update the content
$updatedContent = $content -replace ".*SeNetworkLogonRight.*", $newNetworkLogonLine

# If the line doesn't exist, add it
if (-not ($content -match "SeNetworkLogonRight")) {
    $updatedContent += "`r`nSeNetworkLogonRight = *S-1-5-32-544,*S-1-5-32-555"
}

# Write the modified policy back
$updatedContent | Set-Content $infFile

# Apply the modified policy
Write-Host "Applying security policy changes..." -ForegroundColor Green
secedit /configure /db "$env:TEMP\Security.sdb" /cfg $infFile /areas USER_RIGHTS

# Cleanup temporary files
Remove-Item $infFile -Force -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\Security.sdb" -Force -ErrorAction SilentlyContinue

Write-Host "Fix for V-253480 completed." -ForegroundColor Green
Write-Host "The 'Access this computer from the network' user right is now only assigned to Administrators and Remote Desktop Users groups." -ForegroundColor Cyan

# Define rights modifications for other user rights
$rightsToRemove = @{
    "SeInteractiveLogonRight" = @("No_Guest", "Backup Operators")  # V-253483
    "SeBackupPrivilege" = @("Backup Operators")  # V-253491
    "SeDenyNetworkLogonRight" = @("No_Guest")  # V-253494
    "SeRestorePrivilege" = @("Backup Operators")  # V-253505
}

$rightsToAdd = @{
    "SeDenyNetworkLogonRight" = @("Guests")  # V-253494
    "SeDenyInteractiveLogonRight" = @("Guests")  # V-253495
    "SeDenyRemoteInteractiveLogonRight" = @("Guests", "Everyone")  # V-253505
}

# Remove specified rights
foreach ($right in $rightsToRemove.Keys) {
    foreach ($user in $rightsToRemove[$right]) {
        $content = $content -replace "$right = $user", ""
    }
}

# Add specified rights
foreach ($right in $rightsToAdd.Keys) {
    foreach ($user in $rightsToAdd[$right]) {
        if ($content -match "$right") {
            $content = $content -replace "($right = .*)", "`$1, $user"
        } else {
            $content += "`n$right = $user"
        }
    }
}

# Write the modified policy back
$content | Set-Content $infFile

# Apply the modified policy
Write-Host "Applying security policy changes..." -ForegroundColor Green
secedit /configure /db "$env:TEMP\Security.sdb" /cfg $infFile /areas USER_RIGHTS

# Cleanup temporary files
Remove-Item $infFile -Force -ErrorAction SilentlyContinue
#endregion

#  V-253483: The "Back up files and directories" user right must only be assi
# Check for administrative privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "This script requires administrative privileges. Please run as administrator." -ForegroundColor Red
    exit 1
}

Write-Host "Starting fix for V-253483: Configuring 'Back up files and directories' user right..." -ForegroundColor Cyan

# Create a temporary security policy file
$tempPath = "$env:TEMP\BackupPrivilege.inf"
$verifyPath = "$env:TEMP\VerifyBackupPrivilege.inf"

# First, export current security policy to see what groups currently have this right
Write-Host "Exporting current security policy to check existing rights..." -ForegroundColor Cyan
secedit /export /cfg $verifyPath
$currentRights = Get-Content -Path $verifyPath -Raw
$backupPrivilegeLine = ($currentRights -split "`r`n") | Where-Object { $_ -match "SeBackupPrivilege" }
Write-Host "Current 'Back up files and directories' setting: $backupPrivilegeLine" -ForegroundColor Yellow

# Create the security policy with only Administrators having SeBackupPrivilege
$secpol = @"
[Unicode]
Unicode=yes
[Version]
signature="`$CHICAGO`$"
Revision=1
[Privilege Rights]
SeBackupPrivilege = *S-1-5-32-544
"@

# Write the policy to the temporary file
$secpol | Out-File -FilePath $tempPath -Encoding Unicode -Force

# Apply the modified policy
Write-Host "Applying security policy changes for 'Back up files and directories'..." -ForegroundColor Green
$result = secedit /configure /db "$env:TEMP\SecurityBackup.sdb" /cfg $tempPath /areas USER_RIGHTS /quiet

# Verify the configuration after applying changes
Write-Host "Verifying 'Back up files and directories' configuration after changes..." -ForegroundColor Cyan
secedit /export /cfg $verifyPath
$updatedRights = Get-Content -Path $verifyPath -Raw
$updatedPrivilegeLine = ($updatedRights -split "`r`n") | Where-Object { $_ -match "SeBackupPrivilege" }
Write-Host "Updated 'Back up files and directories' setting: $updatedPrivilegeLine" -ForegroundColor Green

# Clean up temporary files
Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
Remove-Item -Path $verifyPath -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:TEMP\SecurityBackup.sdb" -Force -ErrorAction SilentlyContinue

Write-Host "Configuration of 'Back up files and directories' user right completed." -ForegroundColor Green
Write-Host "The 'Back up files and directories' user right is now only assigned to the Administrators group." -ForegroundColor Cyan

# V-253495 - Configure "Deny log on through Remote Desktop Services" user right
# This script configures the "Deny log on through Remote Desktop Services" user right to prevent access from:
# - Domain Admins
# - Enterprise Admins
# - Local account
# - Guests
# - Everyone

# Check for administrative privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "This script requires administrative privileges. Please run as administrator." -ForegroundColor Red
    exit 1
}

Write-Host "Starting configuration for V-253495: Deny log on through Remote Desktop Services..." -ForegroundColor Cyan

# Create a temporary security policy file
$tempPath = "$env:TEMP\DenyRemoteRDP.inf"
$verifyPath = "$env:TEMP\VerifyDenyRemoteRDP.inf"

# First, export current security policy to see what groups currently have this right
Write-Host "Exporting current security policy to check existing rights..." -ForegroundColor Cyan
secedit /export /cfg $verifyPath
$currentRights = Get-Content -Path $verifyPath -Raw
$denyRemoteRDPLine = ($currentRights -split "`r`n") | Where-Object { $_ -match "SeDenyRemoteInteractiveLogonRight" }
Write-Host "Current 'Deny log on through Remote Desktop Services' setting: $denyRemoteRDPLine" -ForegroundColor Yellow

# Determine system type (domain-joined or standalone)
$computerSystem = Get-WmiObject -Class Win32_ComputerSystem
$isDomainJoined = $computerSystem.PartOfDomain

# Create the security policy with appropriate settings based on system type
if ($isDomainJoined) {
    Write-Host "Domain-joined system detected. Adding Domain Admins and Enterprise Admins to the deny list." -ForegroundColor Green
    
    # For domain-joined systems, include Domain Admins and Enterprise Admins
    $secpol = @"
[Unicode]
Unicode=yes
[Version]
signature="`$CHICAGO`$"
Revision=1
[Privilege Rights]
SeDenyRemoteInteractiveLogonRight = *S-1-1-0,*S-1-5-32-546,*S-1-5-113,*S-1-5-32-544,*S-1-5-32-551
"@
    
    Write-Host "Adding the following groups to 'Deny log on through Remote Desktop Services':" -ForegroundColor Green
    Write-Host "- Everyone (S-1-1-0)" -ForegroundColor Cyan
    Write-Host "- Guests (S-1-5-32-546)" -ForegroundColor Cyan
    Write-Host "- Local account (S-1-5-113)" -ForegroundColor Cyan
    Write-Host "- Domain Admins (via Domain Admins group)" -ForegroundColor Cyan
    Write-Host "- Enterprise Admins (via Enterprise Admins group)" -ForegroundColor Cyan
} else {
    Write-Host "Standalone system detected. Adding local security principals to the deny list." -ForegroundColor Green
    
    # For standalone systems, include Everyone, Guests, and Local account
    $secpol = @"
[Unicode]
Unicode=yes
[Version]
signature="`$CHICAGO`$"
Revision=1
[Privilege Rights]
SeDenyRemoteInteractiveLogonRight = *S-1-1-0,*S-1-5-32-546,*S-1-5-113
"@
    
    Write-Host "Adding the following groups to 'Deny log on through Remote Desktop Services':" -ForegroundColor Green
    Write-Host "- Everyone (S-1-1-0)" -ForegroundColor Cyan
    Write-Host "- Guests (S-1-5-32-546)" -ForegroundColor Cyan
    Write-Host "- Local account (S-1-5-113)" -ForegroundColor Cyan
}

# Write the policy to the temporary file
$secpol | Out-File -FilePath $tempPath -Encoding Unicode -Force

# Apply the modified policy
Write-Host "Applying security policy changes for 'Deny log on through Remote Desktop Services'..." -ForegroundColor Green
$result = secedit /configure /db "$env:TEMP\SecurityDenyRDP.sdb" /cfg $tempPath /areas USER_RIGHTS /quiet

# Verify the configuration after applying changes
Write-Host "Verifying 'Deny log on through Remote Desktop Services' configuration after changes..." -ForegroundColor Cyan
secedit /export /cfg $verifyPath
$updatedRights = Get-Content -Path $verifyPath -Raw
$updatedDenyRemoteRDPLine = ($updatedRights -split "`r`n") | Where-Object { $_ -match "SeDenyRemoteInteractiveLogonRight" }
Write-Host "Updated 'Deny log on through Remote Desktop Services' setting: $updatedDenyRemoteRDPLine" -ForegroundColor Green

# Clean up temporary files
Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
Remove-Item -Path $verifyPath -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:TEMP\SecurityDenyRDP.sdb" -Force -ErrorAction SilentlyContinue

Write-Host "Configuration of 'Deny log on through Remote Desktop Services' user right completed." -ForegroundColor Green
Write-Host "V-253495 remediation completed successfully." -ForegroundColor Cyan

# V-253498 - Configure "Impersonate a client after authentication" user right
Write-Host "Fixing V-253498: 'Impersonate a client after authentication' user right..." -ForegroundColor Cyan

# Create a temporary INF file
$tempInfFile = "$env:TEMP\SeImpersonatePrivilege.inf"

@"
[Unicode]
Unicode=yes
[Version]
signature="`$CHICAGO`$"
Revision=1
[Privilege Rights]
SeImpersonatePrivilege = *S-1-5-19,*S-1-5-20,*S-1-5-32-544,*S-1-5-6
"@ | Out-File -FilePath $tempInfFile -Encoding Unicode -Force

# Apply the security policy
Write-Host "Applying security policy..." -ForegroundColor Green
$result = secedit /configure /db secedit.sdb /cfg "$tempInfFile" /areas USER_RIGHTS /quiet

# Clean up
Remove-Item -Path $tempInfFile -Force -ErrorAction SilentlyContinue
Remove-Item -Path "secedit.sdb" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "secedit.jfm" -Force -ErrorAction SilentlyContinue

Write-Host "V-253498 remediation complete." -ForegroundColor Cyan

# V-253505 - Configure "Restore files and directories" user right to only be assigned to Administrators
Write-Host "Configuring 'Restore files and directories' user right (V-253505)..." -ForegroundColor Green

# Create a temporary security policy file
$tempPath = "$env:TEMP\RestorePrivilege.inf"
$verifyPath = "$env:TEMP\VerifyRestorePrivilege.inf"

# First, export current security policy to see what groups currently have this right
Write-Host "Exporting current security policy to check existing rights..." -ForegroundColor Cyan
secedit /export /cfg $verifyPath
$currentRights = Get-Content -Path $verifyPath -Raw
$restorePrivilegeLine = ($currentRights -split "`r`n") | Where-Object { $_ -match "SeRestorePrivilege" }
Write-Host "Current 'Restore files and directories' setting: $restorePrivilegeLine" -ForegroundColor Yellow

# Create the security policy with only Administrators having SeRestorePrivilege
$secpol = @"
[Unicode]
Unicode=yes
[Version]
signature="`$CHICAGO`$"
Revision=1
[Privilege Rights]
SeRestorePrivilege = *S-1-5-32-544
"@

# Write the policy to the temporary file
$secpol | Out-File -FilePath $tempPath -Encoding Unicode -Force

# Apply the modified policy
Write-Host "Applying security policy changes for 'Restore files and directories'..." -ForegroundColor Green
$result = secedit /configure /db "$env:TEMP\SecurityRestore.sdb" /cfg $tempPath /areas USER_RIGHTS /quiet

# Verify the configuration after applying changes
Write-Host "Verifying 'Restore files and directories' configuration after changes..." -ForegroundColor Cyan
secedit /export /cfg $verifyPath
$updatedRights = Get-Content -Path $verifyPath -Raw
$updatedPrivilegeLine = ($updatedRights -split "`r`n") | Where-Object { $_ -match "SeRestorePrivilege" }
Write-Host "Updated 'Restore files and directories' setting: $updatedPrivilegeLine" -ForegroundColor Green

# Clean up temporary files
Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
Remove-Item -Path $verifyPath -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:TEMP\SecurityRestore.sdb" -Force -ErrorAction SilentlyContinue

Write-Host "Configuration of 'Restore files and directories' user right completed." -ForegroundColor Green

#region CAT3 Findings

# V-253425 Windows 11 must be configured to prevent users from receiving suggestions for third-party or additional applications.
# Check for administrative privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "This script requires administrative privileges. Please run as administrator." -ForegroundColor Red
    exit 1
}

Write-Host "Starting configuration for V-253425: Prevent third-party app suggestions..." -ForegroundColor Cyan

# First, set the policy for the default user profile
Write-Host "Setting DisableThirdPartySuggestions for the default user profile..." -ForegroundColor Green
$defaultUserPath = "$env:SystemDrive\Users\Default"
$defaultUserHivePath = "$defaultUserPath\NTUSER.DAT"

# Load the default user hive
if (Test-Path $defaultUserHivePath) {
    try {
        # Use Start-Process to run reg load with elevated privileges
        $tempFile = [System.IO.Path]::GetTempFileName()
        
        # Create a temporary script to load and modify the hive
        @"
reg load "HKU\DefaultUser" "$defaultUserHivePath"
reg add "HKU\DefaultUser\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableThirdPartySuggestions /t REG_DWORD /d 1 /f
reg unload "HKU\DefaultUser"
"@ | Out-File -FilePath $tempFile
        
        # Execute the temporary script with elevated privileges
        Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$tempFile`"" -Verb RunAs -Wait
        
        # Clean up
        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        
        Write-Host "Successfully set DisableThirdPartySuggestions for the default user profile." -ForegroundColor Green
    }
    catch {
        Write-Host "Error setting registry for default user: $_" -ForegroundColor Red
    }
} else {
    Write-Host "Default user profile not found at $defaultUserHivePath" -ForegroundColor Yellow
}

# Now set the policy for all existing user profiles
Write-Host "Setting DisableThirdPartySuggestions for all existing user profiles..." -ForegroundColor Green

# Get all user profiles
$userProfiles = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*" | 
    Where-Object { $_.ProfileImagePath -like "$env:SystemDrive\Users\*" -and $_.ProfileImagePath -notlike "*$env:SystemDrive\Users\Default*" }

foreach ($profile in $userProfiles) {
    $userProfilePath = $profile.ProfileImagePath
    $username = Split-Path $userProfilePath -Leaf
    $ntUserDatPath = Join-Path $userProfilePath "NTUSER.DAT"
    
    # Skip system accounts
    if ($username -eq "Public" -or $username -eq "systemprofile" -or $username -eq "LocalService" -or $username -eq "NetworkService") {
        continue
    }
    
    Write-Host "Processing user profile: $username" -ForegroundColor Cyan
    
    # Check if the user's NTUSER.DAT exists
    if (Test-Path $ntUserDatPath) {
        # Check if the user is currently logged in
        $userSid = $profile.PSChildName
        $userLoggedIn = $false
        
        try {
            $key = [Microsoft.Win32.Registry]::Users.OpenSubKey($userSid)
            if ($key -ne $null) {
                $userLoggedIn = $true
                $key.Close()
            }
        } catch {
            $userLoggedIn = $false
        }
        
        if ($userLoggedIn) {
            Write-Host "User $username is currently logged in. Setting registry directly..." -ForegroundColor Yellow
            
            # For logged-in users, we can set the registry directly
            $regPath = "Registry::HKEY_USERS\$userSid\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
            if (-not (Test-Path $regPath)) {
                New-Item -Path $regPath -Force | Out-Null
            }
            
            New-ItemProperty -Path $regPath -Name "DisableThirdPartySuggestions" -Value 1 -PropertyType DWORD -Force | Out-Null
            Write-Host "Successfully set DisableThirdPartySuggestions for user $username." -ForegroundColor Green
        } else {
            Write-Host "User $username is not logged in. Loading user hive..." -ForegroundColor Yellow
            
            # For users not logged in, we need to load their hive
            $hiveName = "TempHive_$username"
            reg load "HKU\$hiveName" $ntUserDatPath
            
            # Create the registry path if it doesn't exist
            $regPath = "Registry::HKEY_USERS\$hiveName\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
            if (-not (Test-Path $regPath)) {
                New-Item -Path $regPath -Force | Out-Null
            }
            
            # Set the registry value
            New-ItemProperty -Path $regPath -Name "DisableThirdPartySuggestions" -Value 1 -PropertyType DWORD -Force | Out-Null
            
            # Unload the hive
            [gc]::Collect()
            reg unload "HKU\$hiveName"
            
            Write-Host "Successfully set DisableThirdPartySuggestions for user $username." -ForegroundColor Green
        }
    } else {
        Write-Host "NTUSER.DAT not found for user $username at $ntUserDatPath" -ForegroundColor Yellow
    }
}

# Also set the machine policy as a fallback
Write-Host "Setting machine-wide policy as a fallback..." -ForegroundColor Green
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}
New-ItemProperty -Path $regPath -Name "DisableThirdPartySuggestions" -Value 1 -PropertyType DWORD -Force | Out-Null

Write-Host "Configuration for V-253425 completed successfully." -ForegroundColor Cyan
Write-Host "The DisableThirdPartySuggestions registry value has been set to 1 for all user profiles." -ForegroundColor Green

# V-253482 - Restrict "Allow log on locally" user right to Administrators and Users groups only
# Check for administrative privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "This script requires administrative privileges. Please run as administrator." -ForegroundColor Red
    exit 1
}
Write-Host "Starting configuration for 'Allow log on locally' user right assignment..." -ForegroundColor Cyan

# Create a temporary INF file
$tempInfFile = "$env:TEMP\SeInteractiveLogonRight.inf"

@"
[Unicode]
Unicode=yes
[Version]
signature="`$CHICAGO`$"
Revision=1
[Privilege Rights]
SeInteractiveLogonRight = *S-1-5-32-544,*S-1-5-32-545
"@ | Out-File -FilePath $tempInfFile -Encoding Unicode -Force

# Apply the security policy
Write-Host "Applying security policy..." -ForegroundColor Green
$result = secedit /configure /db secedit.sdb /cfg "$tempInfFile" /areas USER_RIGHTS /quiet

# Clean up
Remove-Item -Path $tempInfFile -Force -ErrorAction SilentlyContinue
Remove-Item -Path "secedit.sdb" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "secedit.jfm" -Force -ErrorAction SilentlyContinue

Write-Host "Configuration complete. Please reboot the system for changes to take effect." -ForegroundColor Cyan

# V-253498 
Write-Host "Testing compliance with V-253498 'Impersonate a client after authentication' user right..." -ForegroundColor Cyan

# Create temporary security policy file
$verifyPath = "$env:TEMP\VerifyImperClientRight.inf"

# Export current security policy
Write-Host "Exporting current security policy to check existing rights..." -ForegroundColor Cyan
secedit /export /cfg $verifyPath
$currentRights = Get-Content -Path $verifyPath -Raw
$impersonateRightLine = ($currentRights -split "`r`n") | Where-Object { $_ -match "SeImpersonatePrivilege" }
Write-Host "Current 'Impersonate a client after authentication' setting: $impersonateRightLine" -ForegroundColor Yellow

# Define the allowed SIDs
$allowedSIDs = @(
    "*S-1-5-32-544", # Administrators
    "*S-1-5-6",      # Service
    "*S-1-5-19",     # Local Service
    "*S-1-5-20"      # Network Service
)

# Extract the SIDs from the current setting
$currentSetting = $impersonateRightLine -replace "SeImpersonatePrivilege = ", ""
$currentSIDs = $currentSetting -split ","

# Check if any unauthorized SIDs are present
$unauthorizedSIDs = $currentSIDs | Where-Object { $sid = $_; -not ($allowedSIDs -contains $sid) }
if ($unauthorizedSIDs) {
    Write-Host "FAILED: Unauthorized SIDs found with 'Impersonate a client after authentication' right:" -ForegroundColor Red
    foreach ($sid in $unauthorizedSIDs) {
        Write-Host "- $sid" -ForegroundColor Red
    }
    Write-Host "V-253498 check failed. Run Fix-V253498.ps1 to remediate." -ForegroundColor Red
    $result = $false
} else {
    # Check if all required SIDs are present
    $missingSIDs = $allowedSIDs | Where-Object { $sid = $_; -not ($currentSIDs -contains $sid) }
    
    if ($missingSIDs) {
        Write-Host "FAILED: Required SIDs missing from 'Impersonate a client after authentication' right:" -ForegroundColor Red
        foreach ($sid in $missingSIDs) {
            Write-Host "- $sid" -ForegroundColor Red
        }
        $result = $false
    } else {
        Write-Host "PASSED: 'Impersonate a client after authentication' right is correctly configured." -ForegroundColor Green
        Write-Host "The right is assigned only to:" -ForegroundColor Green
        Write-Host "- Administrators" -ForegroundColor Cyan
        Write-Host "- Service" -ForegroundColor Cyan
        Write-Host "- Local Service" -ForegroundColor Cyan
        Write-Host "- Network Service" -ForegroundColor Cyan
        Write-Host "V-253498 check passed." -ForegroundColor Green
        $result = $true
    }
}

# Clean up temporary files
Remove-Item -Path $verifyPath -Force -ErrorAction SilentlyContinue

Write-Host "`n=== Addressing CAT3 Findings ===" -ForegroundColor Magenta

# V-253425 - Prevent users from receiving suggestions for third-party applications
Write-Host "Configuring system to prevent third-party app suggestions (V-253425)..." -ForegroundColor Green
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v "DisableThirdPartySuggestions" /t REG_DWORD /d 1 /f

# V-253477 - Toast notifications to the lock screen must be turned off
# This implementation can be added to the main Windows11_StandAlone_MAC3_Public_Profile.ps1 script

Write-Host "`n=== Addressing CAT3 Finding - V-253477 ===" -ForegroundColor Magenta

Write-Host "Disabling toast notifications on the lock screen (V-253477)..." -ForegroundColor Green

# Create the registry path if it doesn't exist
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications"
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
    Write-Host "Created registry path: $regPath" -ForegroundColor Cyan
}

# Set the registry value
Set-ItemProperty -Path $regPath -Name "NoToastApplicationNotificationOnLockScreen" -Value 1 -Type DWord
Write-Host "Set NoToastApplicationNotificationOnLockScreen registry value to 1" -ForegroundColor Green

# Also set for the current user
$userRegPath = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications"
if (-not (Test-Path $userRegPath)) {
    New-Item -Path $userRegPath -Force | Out-Null
}
Set-ItemProperty -Path $userRegPath -Name "NoToastApplicationNotificationOnLockScreen" -Value 1 -Type DWord

# Verify the setting was applied correctly
$verifyValue = Get-ItemProperty -Path $regPath -Name "NoToastApplicationNotificationOnLockScreen" -ErrorAction SilentlyContinue
if ($verifyValue -ne $null -and $verifyValue.NoToastApplicationNotificationOnLockScreen -eq 1) {
    Write-Host "Verified: Toast notifications on the lock screen have been disabled successfully." -ForegroundColor Green
} else {
    Write-Host "Warning: Could not verify toast notification setting. Please check manually." -ForegroundColor Yellow
}

Write-Host "V-253477 remediation completed." -ForegroundColor Green
# Alternative method using reg add command (as a fallback)
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications" /v NoToastApplicationNotificationOnLockScreen /t REG_DWORD /d 1 /f

Write-Host "`nWindows 11 STIG Hardening Script completed." -ForegroundColor Cyan
Write-Host "Note that some findings require manual intervention:" -ForegroundColor Yellow
Write-Host "- V-253257: Secure Boot must be enabled (requires BIOS/UEFI configuration)" -ForegroundColor Yellow
Write-Host "- V-253427 to V-253430: DoD certificates installation requires manual intervention" -ForegroundColor Yellow
Write-Host "A system restart is recommended to apply all changes." -ForegroundColor Cyan
Write-Host "Run 'gpupdate /force' to apply Group Policy changes." -ForegroundColor Yellow
Write-Host "If you get a Bitlocker Error after rebooting in UEFI mode, you forgot to disable Bitlocker before rebooting." -ForegroundColor Red
Write-Host "After booting in Legacy mode, reset the bitlocker registry keys added by this script." -ForegroundColor Yellow 
Write-Host "(HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\SecureBoot\State\UEFISecureBootEnabled\value = '0'" -ForegroundColor Green
Write-Host "failed test of 'equals' compared to '1').  If you are already in UEFI mode, You should not have a problem." -ForegroundColor Yellow
