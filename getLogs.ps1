#Script made by: Dylan Pope
#Date: 01/31/2025
#Purpose: This script will export system logs and minidumps to the user's desktop.

param(
  [switch] $noCompress
)

# Check if the script is running with administrator rights
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
  # Relaunch the script with administrator rights, preserving parameters
  $arguments = "-File `"$($MyInvocation.MyCommand.Path)`""
  if ($noCompress)
  {
    $arguments += " -noCompress"
  }
  Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments
  return
}

# Get current user's desktop path
$global:currentUser = (Get-CimInstance -ClassName Win32_ComputerSystem).Username
$global:currentUser = $global:currentUser.split('\')[-1]
$global:desktopPath = "C:\Users\$currentUser\Desktop"
$global:logFolder = Join-Path -Path $desktopPath -ChildPath "\Logs"
$global:compressedPath = Join-Path -Path $desktopPath -ChildPath "\Logs.zip"

if (!(Test-Path $logFolder))
{
  mkdir $logFolder
}

if (Test-Path $logFolder)
{
  Write-Host "Found dirty environment cleaning up." -ForegroundColor Yellow
  Remove-Item "$logFolder\*.evtx"
}

if (Test-Path $compressedPath)
{
  Write-Host "Found dirty environment cleaning up." -ForegroundColor Yellow
  Remove-Item $compressedPath
}

function Get-Logs
{
  $systemLogFileName = "SystemLogs_$(Get-Date -Format 'yyyyMMdd_HHmmss').evtx"
  $applicationLogFileName = "ApplicationLogs_$(Get-Date -Format 'yyyyMMdd_HHmmss').evtx"
  $systemLogOutputPath = Join-Path -Path $logFolder -ChildPath $systemLogFileName
  $applicationLogOutputPath = Join-Path -Path $logFolder -ChildPath $applicationLogFileName
  # Export system logs (errors and warnings) from the last 2 months.
  #$startDate = (Get-Date).AddDays(-60)
  #$endDate = Get-Date
  wevtutil export-log System $systemLogOutputPath
  wevtutil export-log Application $applicationLogOutputPath
  Write-Host "System logs have been exported to: $systemLogFileName and $applicationLogFileName" -ForegroundColor Green
}

function Get-Minidumps
{
  $minidumpPath = "C:\Windows\Minidump\*"
  $minidumpDestination = Join-Path -Path $logFolder -ChildPath "\Minidump\"
  if (!(Test-Path $minidumpDestination))
  {
    mkdir $minidumpDestination
  }
  try
  {
    Write-Host "Moving files from $minidumpPath to $minidumpDestination"
    copy-item -Path $minidumpPath -Destination $minidumpDestination -Recurse
  } catch
  {
    Write-Host "Error moving minidump files." -ForegroundColor Red
    if (!(Test-Path $minidumpPath))
    {
      Write-Host "No minidumps found." -ForegroundColor Yellow
    }
    Read-Host "Press enter to exit."
  }
} 

function Start-Compression
{
  param(
    [switch] $noCompress
  )
  if (!($noCompress))
  {
    $logPath = Join-Path -Path $logFolder -ChildPath "\*"
    Compress-Archive -Path $logPath -DestinationPath $compressedPath
    if (Test-Path $compressedPath)
    {
      Write-Host "Successfully compressed logs. Cleaning up." -ForegroundColor Green
      remove-item $logFolder -Recurse
    }
  }
}

Write-Host "compress $noCompress"

function main
{
  Get-Logs
  Get-Minidumps
  Start-Compression -noCompress:$noCompress
}

main
Write-Host "The logs have been saved to your desktop. You can now send the folder named 'Logs' to your support contact." -ForegroundColor Green
Read-Host "Press enter to exit."
