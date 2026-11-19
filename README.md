Recon - Both below are scripts for nmapping the specific one is hardcoded to likely class info, the generic one takes more inputs so it can be used if the enviornment is changed
generic_recon.sh
specific_recon.sh

Initial access - Anonymous FTP, SMB shares, website links, and possible entry points. Run from Kali

./initial_access_enum.sh 172.16.10.171 172.16.10.11

Linux Privilege Escalation -Sudo permissions, SUID binaries, users, cron, and systemd timers. Run on Linux target

bash /tmp/linux_privesc_enum.sh


Windows / Active Directory

Domain users, groups, SPNs, GPOs, and dangerous permissions. Run in Windows PowerShell.

.\ad_enum.ps1
