# Windows 11 STIG Hardening - MAC3 Public Profile

![Security Shield](images/RobotArmor.png "Windows 11 Security Hardening")

## Overview

This documentation covers the Windows 11 STIG Hardening script (`Windows11_StandAlone_MAC3_Public_Profile.ps1`) that implements security controls based on the Windows 11 Security Technical Implementation Guide (STIG). The script addresses CAT1 (Critical), CAT2 (High), and CAT3 (Medium) findings to achieve compliance with the MAC 3 - Public profile requirements.

The hardening script works towards compliance with the MAC 3 - Public profile based on current findings from the SCAP Compliance Checker (SCC) 5.10.2. These checks apply to Windows 11 Professional builds that are not connected to an Active Directory domain. The aim is to provide a secure build for general corporate use while maintaining usability.

## Script Development

The remediation steps implemented in this script were generated using:

1. Amazon Q artificial intelligence to analyze and address STIG findings
2. Remediation steps from the paper "Using PowerShell & Other Command Line Tools for Windows 11 STIG Compliance" by Rudy Pankratz (December 2023)
3. Additional research and testing by Jesse Bacon

## Configuration

The script uses a JSON configuration file to customize settings:

```json
{
    "AccountNames": {
        "AdminAccountName": "executive",
        "GuestAccountName": "No_Guest"
    },
    "BitLocker": {
        "MinimumPINLength": 6,
        "RequireStartupPIN": true
    },
    "EventLogs": {
        "ApplicationLogSize": 32768,
        "SecurityLogSize": 1024000,
        "SystemLogSize": 32768
    },
    "AccountPolicies": {
        "LockoutDuration": 15,
        "LockoutThreshold": 3,
        "LockoutWindow": 15,
        "UniquePasswordHistory": 24,
        "MaxPasswordAge": 60,
        "MinPasswordAge": 1,
        "MinPasswordLength": 14
    },
    "LegalNotice": {
        "Caption": "This is an official corporate system belonging to a commercial entity (Flatstone Services, L.L.C.).",
        "Text": "This system may contain PII, intellectual property or material that is sensitive to an individual, a business or the United States federal government. Damages to this system or the property of this system or the operator of this system may be assessed financially to multiple parties. Within the appropriate rules of engagement, GO's and NGO's may take protective actions on behalf of this system."
    },
    "InactivityTimeout": 900
}
```

These configuration parameters can be adjusted to meet specific organizational requirements while maintaining STIG compliance.

## Key Security Features

The script implements comprehensive security controls including:

- **BitLocker Encryption**: Pre-boot authentication with PIN requirements
- **Account Security**: Password complexity, history, and lockout policies
- **Audit Policies**: Comprehensive event logging for security monitoring
- **Network Security**: IPv4/IPv6 protections, ICMP redirect controls
- **Application Controls**: Disabling of autorun, autoplay, and unnecessary services
- **Privacy Settings**: Control of telemetry, app inventory, and data collection
- **Authentication Security**: WDigest, NTLM settings, and credential protection
- **User Rights**: Proper assignment of security privileges

## Findings Addressed

The script addresses over 100 STIG findings across all severity categories:

### CAT1 (Critical) Findings

| Finding ID | Description | Implementation |
|------------|-------------|----------------|
| V-253260 | BitLocker PIN for pre-boot authentication | Registry settings for BitLocker configuration |
| V-253386 | Autoplay for non-volume devices | Registry settings to disable autoplay |
| V-253387 | Default autorun behavior | Registry settings to prevent autorun commands |
| V-253283 | Data Execution Prevention (DEP) | BCDEDIT command to enable DEP |
| V-253284 | Exception Chain Validation | Registry setting to disable exception chain validation |

### CAT2 (High) Findings

| Finding ID | Description | Implementation |
|------------|-------------|----------------|
| V-253273 | Password expiration | Set-LocalUser cmdlet to require password expiration |
| V-253285, V-253286 | PowerShell V2 and SMB1Protocol | Disable-WindowsOptionalFeature to remove insecure features |
| V-253289 | Secondary Logon Service | Set-Service to disable the service |
| V-253304 | Password complexity | Secedit to configure password complexity |
| V-253305 - V-253336 | Audit policies | Auditpol commands to enable required auditing |
| V-253351 | Camera control | Registry setting to disable camera |
| V-253445 | Legal notice | Registry settings for logon banner |
| V-253498 | Impersonate a client after authentication | Secedit to configure user right assignment |
| V-268317 | Disable Copilot | Registry setting to disable Windows Copilot |

### CAT3 (Medium) Findings

| Finding ID | Description | Implementation |
|------------|-------------|----------------|
| V-253425 | Third-party app suggestions | Registry settings to disable suggestions |
| V-253477 | Toast notifications on lock screen | Registry setting to disable lock screen notifications |

## Manual Intervention Required

Some findings require manual intervention and cannot be fully automated:

1. **V-253257: Secure Boot must be enabled**
   - Requires BIOS/UEFI configuration
   - During the boot process, press the key to enter BIOS/UEFI setup (F1, F2, F10, F12, ESC, or Delete)
   - Navigate to the Secure Boot settings (typically under Security or Boot sections)
   - Enable Secure Boot and save changes
   - Verify with `Confirm-SecureBootUEFI` in PowerShell after reboot

2. **V-253427 to V-253430: DoD certificates installation**
   - Requires obtaining certificate files from authorized sources
   - The script includes placeholder URLs that need to be replaced with actual certificate URLs

## Usage Instructions

### Prerequisites

- Windows 11 Professional system
- Administrative privileges
- PowerShell 5.1 or later

### Running the Script

1. Review and modify the configuration file as needed
2. Run the script as Administrator:

```powershell
.\Windows11_StandAlone_MAC3_Public_Profile.ps1
```

3. Restart the system to apply all changes
4. Run `gpupdate /force` to apply Group Policy changes

## Verification

After applying the hardening script, you can verify compliance using the SCAP Compliance Checker (SCC) 5.10.2:

1. Download the SCC from: [SCC 5.10.2 Windows Bundle](https://dl.dod.cyber.mil/wp-content/uploads/stigs/zip/scc-5.10.2_Windows_bundle.zip)
2. Download the SCAP content from: [Windows 11 V2R4 STIG SCAP 1-3 Benchmark](https://dl.dod.cyber.mil/wp-content/uploads/stigs/zip/U_MS_Windows_11_V2R4_STIG_SCAP_1-3_Benchmark.zip)
3. Run the SCC against your system to verify compliance

## Known Issues

1. **V-268317 - Disable Copilot**: The current registry setting to disable Windows Copilot does not appear to be effective in Windows 11. If you have a working solution, please contribute a fix.

## Troubleshooting

If you encounter issues during script execution:

1. **Audit Policy Errors**: Ensure you're running with administrative privileges and use the provided `fix_audit_policies_elevated.ps1` script
2. **Legal Notice Issues**: Verify the config.json file has the correct format for legal notice caption and text
3. **Registry Errors**: Some settings may require a system restart before they take effect
4. **Permission Denied**: Run PowerShell as Administrator with the command `Start-Process PowerShell -Verb RunAs`

## Additional Scripts

### User Rights Assignment Scripts

The repository includes additional scripts to address specific user rights assignments:

| Script Name | Purpose | STIG Finding |
|-------------|---------|--------------|
| Configure-ImpersonateClientRight.ps1 | Configures the "Impersonate a client after authentication" user right to be assigned only to Administrators, Service, Local Service, and Network Service | VV-253498 |
| Test-ImpersonateClientRight.ps1 | Tests if the "Impersonate a client after authentication" user right is correctly configured | VV-253498 |

To use these scripts:

1. Run the configuration script as Administrator:
```powershell
.\Configure-ImpersonateClientRight.ps1
```

2. Verify the configuration with the test script:
```powershell
.\Test-ImpersonateClientRight.ps1
```

## Additional Resources

- [SCC 5.10.2 README](https://dl.dod.cyber.mil/wp-content/uploads/stigs/txt/SCC_5.10.2_Readme.txt)
- [SANS Paper: Using PowerShell & Other Command Line Tools for Windows 11 STIG Compliance](https://www.sans.edu/cyber-research/using-powershell-other-command-line-tools-windows-11-stig-compliance/) by Rudy Pankratz

## Notes

- Always back up your system before applying security hardening scripts
- Some settings may affect system functionality; test in a non-production environment first
- For certificate installation, ensure you have the correct certificate files from authorized sources
- The Secure Boot requirement must be configured in the system BIOS/UEFI

## Results

![STIG Compliance Score](images/Score.png "Windows 11 STIG Compliance Score")

The hardening script achieves a final STIG compliance score of 97.24%, addressing the majority of security findings while maintaining system usability.

## Next Steps

![Next Steps](images/NextSteps.png "Required Next Steps")

After running the hardening script, the following manual steps are required to achieve full compliance:

1. **Install DoD Certificates**:
   - Download and install the required DoD certificates from authorized sources
   - Import the certificates into the appropriate certificate stores

2. **Disable Microsoft Copilot**:
   - While the script attempts to disable Copilot via registry settings, additional steps may be required
   - Consider using Group Policy or additional registry modifications if Copilot remains active

## Contributors
Jesse Bacon  
Amazon Q  
Microsoft Copilot