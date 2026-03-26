@echo off
REM deploy.bat - CMD wrapper for the PowerShell deployment script
REM Usage: deploy.bat -Server <host> -KeyPath <path> [options]
REM
REM This script simply calls deploy.ps1 with the same arguments.
REM For full documentation, run: powershell -File deploy.ps1 -?
REM
REM Examples:
REM   deploy.bat -Server 192.168.1.100 -KeyPath C:\Users\me\.ssh\id_rsa
REM   deploy.bat -Server myserver.com -SshPort 2222 -SkipBuild

powershell -ExecutionPolicy Bypass -File "%~dp0deploy.ps1" %*
