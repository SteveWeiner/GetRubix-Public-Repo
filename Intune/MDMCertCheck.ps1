# MDM Certificate check
# This script checks a PC to see if there is a valid MDM Intune Certificate

$cert = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Issuer -eq "Microsoft Intune MDM Device CA" }

if ($cert) {
    Write-Host "Intune certificate found on the device"
} else {
    Write-Host "No Intune cert found."
}