#!/usr/bin/env pwsh

# Prompt the user for input
$string = Read-Host "Enter the string to encode"

# Convert the string to a byte array
$bytes = [System.Text.Encoding]::Unicode.GetBytes($string)

# Convert the byte array to a base64 encoded string
$base64String = [Convert]::ToBase64String($bytes)

# Print the encoded string
Write-Output $base64String

