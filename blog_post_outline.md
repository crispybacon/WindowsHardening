# Windows 11 STIG Hardening: Achieving MAC3 Compliance

## Introduction

In today's cybersecurity landscape, securing Windows 11 systems is critical for organizations handling publicly releasable information. The Windows 11 STIG Hardening script implements security controls based on the Windows 11 Security Technical Implementation Guide (STIG) to achieve MAC 3 - Public profile compliance.

This blog post outlines the purpose, implementation, and verification of this hardening script, ensuring a secure Windows 11 build for general corporate use.

## A Note About the Human Element

ll throughout my career I encountered people in the network security environment who were adamantly opposed to automation.  In the early days of SIEM engineering and analysis I was greeted with comments such as "Automate that and I'll fire you!" or "Nobdy ever did automate, that... Think about it".  Some environments were more hostile than others and at times there have been people who were willing to make death threats about what could be automatically configured from event management systems.  The reason is there are jobs within corporate entities and the government that rely on these things never being automated.  This is not because the government is stupid and operating at a sub-par level.  The reason it never gets automated is the main focus of those environments is identifying people who are not fit to work in a specified process.  They will work slowly if told to by another or they will stick to an antiquated procedure when outside of the time in their life where they are comfortable learning a new thing.  All of my emotional parts burn brightly for the heart-ache and sorrow of the people affected by automation.  At a higher magnitude, people are affected by AI.  As a corporate entity or federal employee I do not care what the impact is to these people.  My business or my infrastructure will need to operate as efficiently and securely as possible or the enemy systems will usurp it.  

## A Note About the Complexity of these Operations

After watching the tutorial videos for SCC I wasted about half a day working with an old chef script to apply these remediations and eventually settled on using Amazon Q and Microsoft Copilot to complete this work.  I can do this a private entity and have, so there.  Please feel free to reap the benefits of this research.  With AI agents reviewing the SCC report, this script took about one day to develop.  There is not going to be a return to the old days of hand rolled scrupting.  It hurts,  that is where I did shine the brightest, in my groups, but AI agents are today just as capable and will be more capable in less than a year's time. 

## The Modern Security Landscape

The cybersecurity environment has evolved dramatically in recent years. With the rise of sophisticated threats and regulatory requirements, organizations must implement robust security controls to protect their systems and data. Windows 11 provides enhanced security features, but proper configuration according to established standards is essential.

The MAC 3 - Public profile represents a balanced approach to security for systems handling publicly releasable information, providing strong protection while maintaining usability for everyday business operations.

## Script Development & Automation

The Windows 11 STIG Hardening script was developed using:

1. Amazon Q AI for analyzing STIG findings and generating remediation code
2. Remediation steps from Rudy Pankratz's paper on PowerShell security hardening
3. Additional research and testing to refine security configurations

The script automates security settings using PowerShell, ensuring compliance with STIG requirements while allowing customization for organizational needs through a configuration file. This approach dramatically reduces the time required to secure systems while ensuring consistency across deployments.

## Key Security Enhancements

The script addresses CAT1 (Critical), CAT2 (High), and CAT3 (Medium) findings, implementing security measures such as:

- BitLocker PIN enforcement for pre-boot authentication
- Disabling insecure features like PowerShell V2 and SMB1
- Account policies enforcing password complexity and lockout thresholds
- Audit policies ensuring comprehensive event logging for security monitoring
- Registry modifications to disable autorun, autoplay, and unnecessary services
- Network security controls to prevent common attack vectors
- User rights assignments to enforce principle of least privilege

These controls work together to create a defense-in-depth approach that significantly reduces the attack surface of Windows 11 systems.

## Verification & Compliance Checks

After applying the hardening script, compliance can be verified using the SCAP Compliance Checker (SCC) 5.10.2:

1. Download SCC and the Windows 11 STIG SCAP Benchmark
2. Run SCC against the hardened system to validate security settings
3. Review findings and adjust configurations as needed

This verification process ensures that all required security controls are properly implemented and functioning as expected.

## Balancing Security and Usability

While security is paramount, the script is designed to maintain usability for end users. The configuration file allows organizations to customize settings based on their specific requirements, ensuring that security controls don't unnecessarily impede productivity.

For example, the inactivity timeout can be adjusted based on organizational policy, and legal notice text can be customized to reflect specific requirements.

## Conclusion

The Windows 11 STIG Hardening script provides a robust security foundation for MAC 3 Public compliance, ensuring protection against vulnerabilities while maintaining usability. By leveraging automation, PowerShell, and STIG guidelines, organizations can streamline security remediation and enhance system resilience.

This approach not only improves security posture but also reduces the time and effort required to maintain compliance, allowing IT teams to focus on other critical tasks.

For further details, refer to the full documentation and security benchmarks. Stay secure, stay compliant!

## References

- Using PowerShell & Other Command Line Tools for Windows 11 STIG Compliance by Rudy Pankratz
- [SCC 5.10.2 Windows Bundle](https://dl.dod.cyber.mil/wp-content/uploads/stigs/zip/scc-5.10.2_Windows_bundle.zip)
- [Windows 11 V2R4 STIG SCAP 1-3 Benchmark](https://dl.dod.cyber.mil/wp-content/uploads/stigs/zip/U_MS_Windows_11_V2R4_STIG_SCAP_1-3_Benchmark.zip)
- [SCC 5.10.2 README](https://dl.dod.cyber.mil/wp-content/uploads/stigs/txt/SCC_5.10.2_Readme.txt)
- [SCC Tutorial Videos](https://dl.dod.cyber.mil/wp-content/uploads/stigs/zip/scc-5.10.2_Windows_bundle.zip)