#!/usr/bin/env pwsh
# Copyright 2018 the K0s authors. All rights reserved. MIT license.
# TODO(everyone): Keep this script simple and easily auditable.

$ErrorActionPreference = 'Stop'

$Version = if ($args.Length -gt 0) {
  $args.Get(0)
} else {
  "latest"
}

if ($PSVersionTable.PSEdition -ne 'Core') {
  $IsWindows = $true
  $IsMacOS = $false
}

$K0sInstall = $env:K0S_INSTALL
$BinDir = if ($K0sInstall) {
  if ($IsWindows) {
    "$K0sInstall\bin"
  } else {
    "$K0sInstall/bin"
  }
} elseif ($IsWindows) {
  "$Home\.k0s\bin"
} else {
  "$Home/.k0s/bin"
}

$Zip = if ($IsWindows) {
  'zip'
} else {
  'tar.gz'
}

$K0sZip = if ($IsWindows) {
  "$BinDir\k0s.$Zip"
} else {
  "$BinDir/k0s.$Zip"
}

$K0sExe = if ($IsWindows) {
  "$BinDir\k0s.exe"
} else {
  "$BinDir/k0s"
}

$OS = if ($IsWindows) {
  'windows'
} else {
  if ($IsMacOS) {
    'darwin'
  } else {
    'linux'
  }
}

# GitHub requires TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$K0sUri = if (!$Version) {
  $Response = Invoke-WebRequest 'https://github.com/btwiuse/k0s/releases' -UseBasicParsing
  if ($PSVersionTable.PSEdition -eq 'Core') {
    $Response.Links |
      Where-Object { $_.href -like "/btwiuse/k0s/releases/download/*/k0s-${OS}-amd64.$Zip" } |
      ForEach-Object { 'https://github.com' + $_.href } |
      Select-Object -First 1
  } else {
    $HTMLFile = New-Object -Com HTMLFile
    if ($HTMLFile.IHTMLDocument2_write) {
      $HTMLFile.IHTMLDocument2_write($Response.Content)
    } else {
      $ResponseBytes = [Text.Encoding]::Unicode.GetBytes($Response.Content)
      $HTMLFile.write($ResponseBytes)
    }
    $HTMLFile.getElementsByTagName('a') |
      Where-Object { $_.href -like "about:/btwiuse/k0s/releases/download/*/k0s-${OS}-amd64.$Zip" } |
      ForEach-Object { $_.href -replace 'about:', 'https://github.com' } |
      Select-Object -First 1
  }
} else {
  "https://github.com/btwiuse/k0s/releases/download/$Version/k0s-${OS}-amd64.$Zip"
}

if (!(Test-Path $BinDir)) {
  New-Item $BinDir -ItemType Directory | Out-Null
}

Invoke-WebRequest $K0sUri -OutFile $K0sZip -UseBasicParsing

if ($IsWindows) {
  Expand-Archive $K0sZip -Destination $BinDir -Force
  Remove-Item $K0sZip
} else {
  gunzip -df $K0sZip
}

if ($IsWindows) {
  $User = [EnvironmentVariableTarget]::User
  $Path = [Environment]::GetEnvironmentVariable('Path', $User)
  if (!(";$Path;".ToLower() -like "*;$BinDir;*".ToLower())) {
    [Environment]::SetEnvironmentVariable('Path', "$Path;$BinDir", $User)
    $Env:Path += ";$BinDir"
  }
  Write-Output "k0s was installed successfully to $K0sExe"
  Write-Output "Run 'k0s -version' to get started"
} else {
  chmod +x "$BinDir/k0s"
  Write-Output "k0s was installed successfully to $K0sExe"
  if (Get-Command k0s -ErrorAction SilentlyContinue) {
    Write-Output "Run 'k0s -version' to get started"
  } else {
    Write-Output "Manually add the directory to your `$HOME/.bash_profile (or similar)"
    Write-Output "  export PATH=`"${BinDir}:`$PATH`""
    Write-Output "Run '$K0sExe -version' to get started"
  }
}
