# Windows 11 STIG Hardening - MAC3 Public Profile

## Overview

This documentation covers the Windows 11 STIG Hardening script (`Windows11_StandAlone_MAC3_Public_Profile.ps1`) that implements security controls based on the Windows 11 Security Technical Implementation Guide (STIG). The script addresses CAT1 (Critical), CAT2 (High), and CAT3 (Medium) findings to achieve compliance with the MAC 3 - Public profile requirements.

The hardening script works towards compliance with the MAC 3 - Public profile based on current findings from the SCAP Compliance Checker (SCC) 5.10.2. These checks apply to Windows 11 Professional builds that are not connected to an Active Directory domain. The aim is to provide a secure build for general corporate use.

## MAC Profiles and Their Purpose

MAC (Mandatory Access Control) profiles define different security postures for systems based on their intended use and security requirements. The Department of Defense (DoD) defines three primary MAC levels:

1. **MAC 1 - Classified**: For systems handling classified information, requiring the highest level of security controls.
2. **MAC 2 - Sensitive**: For systems handling sensitive but unclassified information, requiring moderate to high security controls.
3. **MAC 3 - Public**: For systems handling publicly releasable information, requiring baseline security controls.

Each MAC level is further divided into profiles based on the system's role (e.g., standalone, member server, domain controller). The MAC 3 - Public profile represents the baseline security posture for systems that handle publicly releasable information but still require protection against common threats and vulnerabilities.

## Script Development

The remediation steps implemented in this script were generated using:

1. Amazon Q artificial intelligence to analyze and address STIG findings
2. Remediation steps from the paper "Using PowerShell & Other Command Line Tools for Windows 11 STIG Compliance" by Rudy Pankratz (December 5, 2024)
3. Additional research and testing by Jesse Bacon

## Configuration

The script uses a configuration section to customize certain settings:

```powershell
$config = @{
    AccountNames = @{
        AdminAccountName = "Joker"
        GuestAccountName = "No_Guest"
    }
    BitLocker = @{
        MinimumPINLength = 6
    }
    EventLogs = @{
        ApplicationLogSize = 32768
        SecurityLogSize = 1024000
        SystemLogSize = 32768
    }
    AccountPolicies = @{
        LockoutDuration = 15
        LockoutThreshold = 3
        LockoutWindow = 15
        UniquePasswordHistory = 24
        MaxPasswordAge = 60
        MinPasswordAge = 1
        MinPasswordLength = 14
    }
    LegalNotice = {
        Caption = "DoD Notice and Consent Banner"
        Text = "You are accessing a U.S. Government information system..."
    }
    InactivityTimeout = 900
}
```

These configuration parameters can be adjusted to meet specific organizational requirements while maintaining STIG compliance.

## Findings Addressed

The findings listed below are implemented in addition to those covered in the paper ["Using PowerShell & Other Command Line Tools for Windows 11 STIG Compliance"](https://www.sans.edu/cyber-research/using-powershell-other-command-line-tools-windows-11-stig-compliance/) by Rudy Pankratz linked at the SANS website.

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
| V-253297 - V-253303 | Account lockout and password policies | Net accounts commands to set password policies |
| V-253304 | Password complexity | Secedit to configure password complexity |
| V-253305 - V-253336 | Audit policies | Auditpol commands to enable required auditing |
| V-253337 - V-253339 | Event log sizes | Limit-EventLog to set appropriate log sizes |
| V-253351 | Camera control | Registry setting to disable camera |
| V-253352 | Lock screen slide shows | Registry setting to disable lock screen slideshows |
| V-253380, V-253381 | Password on resume from sleep | Registry settings for sleep state authentication |
| V-253414 | PowerShell script block logging | Registry setting to enable script block logging |
| V-253444 | Machine inactivity limit | Registry setting for screen lock timeout |
| V-253445 | Legal notice | Registry settings for logon banner |
| V-253460 | Kerberos encryption types | Registry setting for encryption types |
| V-253480 - V-253505 | User rights assignments | Secedit to configure user rights |
| V-268317 | Disable Copilot | Registry setting to disable Windows Copilot |

### CAT3 (Medium) Findings

| Finding ID | Description | Implementation |
|------------|-------------|----------------|
| V-253425 | Third-party app suggestions | Registry settings to disable suggestions |
| V-253477 | Toast notifications on lock screen | Registry setting to disable lock screen notifications |

### Additional Security Settings

The script also implements numerous additional security settings, including:

- Network security settings (IPv4/IPv6 source routing, ICMP redirect, etc.)
- Authentication security (WDigest, NTLM settings, etc.)
- Remote access controls (WinRM, Terminal Services, etc.)
- Application security (Windows Installer, SmartScreen, etc.)
- Privacy settings (telemetry, app inventory, etc.)

## Manual Intervention Required

Some findings require manual intervention and cannot be fully automated:

1. **V-253257: Secure Boot must be enabled**
   - Requires BIOS/UEFI configuration
   - During the boot process, press the key to enter BIOS/UEFI setup (F1, F2, F10, F12, ESC, or Delete)
   - Navigate to the Secure Boot settings (typically under Security or Boot sections)
   - Enable Secure Boot and save changes
   - Verify with `Confirm-SecureBootUEFI` in PowerShell after reboot

2. **V-253427 to V-253430: DoD certificates installation**
   - Requires obtaining certificate files from authorized DoD sources
   - The script includes placeholder URLs that need to be replaced with actual certificate URLs

## Usage Instructions

### Prerequisites

- Windows 11 Professional system
- Administrative privileges
- PowerShell 5.1 or later

### Running the Script

1. Review and modify the configuration section as needed
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

## Additional Resources

- [SCC 5.10.2 README](https://dl.dod.cyber.mil/wp-content/uploads/stigs/txt/SCC_5.10.2_Readme.txt)
- [SCC Tutorial Videos](https://dl.dod.cyber.mil/wp-content/uploads/stigs/zip/scc-5.10.2_Windows_bundle.zip)
- [SANS Paper: Using PowerShell & Other Command Line Tools for Windows 11 STIG Compliance](https://www.sans.edu/cyber-research/using-powershell-other-command-line-tools-windows-11-stig-compliance/) by Rudy Pankratz

## Notes

- Always back up your system before applying security hardening scripts
- Some settings may affect system functionality; test in a non-production environment first
- For DoD certificate installation, ensure you have the correct certificate files from authorized sources
- The Secure Boot requirement must be configured in the system BIOS/UEFI