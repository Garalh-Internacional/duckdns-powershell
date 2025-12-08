# Updated for PowerShell 7 compatibility.
# Original: https://github.com/ataylor32/duckdns-powershell
<#
.SYNOPSIS
	Updates the IP address of your Duck DNS domain(s) and emits a result object.
.DESCRIPTION
	Updates the IP address of your Duck DNS domain(s). Intended to be run as a
	scheduled task. This version is compatible with PowerShell 7+ and Windows
	PowerShell and always writes a result object to stdout so automation can
	inspect the result.
.PARAMETER Domains
	A comma-separated list (or array) of your Duck DNS domains to update.
.PARAMETER Token
	Your Duck DNS token.
.PARAMETER IP
	The IP address to use. If you leave it blank, Duck DNS will detect your
	gateway IP.
#>

Param (
	[Parameter(
		Mandatory=$True,
		HelpMessage="Comma separate the domains if you want to update more than one. You may also pass an array of domain names."
	)]
	[ValidateNotNullOrEmpty()]
	[Alias("Domain")]
	[string[]]$Domains,

	[Parameter(Mandatory=$True)]
	[ValidateNotNullOrEmpty()]
	[string]$Token,

	[string]$IP
)

# Normalize domains to a single comma-separated string (accepts array or single string)
if ($Domains -is [System.Array]) {
	$DomainsString = ($Domains -join ',').Trim()
} else {
	$DomainsString = $Domains.Trim()
}

# Ensure values passed to EscapeDataString are never $null
$DomainsEsc = [uri]::EscapeDataString($DomainsString)
$TokenEsc = [uri]::EscapeDataString($Token)
$IPEsc = [uri]::EscapeDataString(($IP -ne $null) ? $IP : '')

$URL = "https://www.duckdns.org/update?domains={0}&token={1}&ip={2}" -f $DomainsEsc, $TokenEsc, $IPEsc

Write-Debug "`$URL set to $URL"
Write-Verbose "Sending update request to Duck DNS..."

# Helper to coerce various response types into a string safely
function Convert-ToString {
	param([Parameter(Mandatory=$true)][object]$InputObj)

	if ($InputObj -eq $null) { return $null }

	# If it's a byte array, assume UTF8
	if ($InputObj -is [byte[]]) {
		try {
			return [System.Text.Encoding]::UTF8.GetString([byte[]]$InputObj)
		} catch {
			# fallback: ASCII
			return [System.Text.Encoding]::ASCII.GetString([byte[]]$InputObj)
		}
	}

	# If it's already a string
	if ($InputObj -is [string]) {
		return $InputObj
	}

	# If it's a stream, read it
	if ($InputObj -is [System.IO.Stream]) {
		try {
			$sr = New-Object System.IO.StreamReader($InputObj)
			$ret = $sr.ReadToEnd()
			$sr.Close()
			return $ret
		} catch {}
	}

	# Some Invoke-WebRequest results include a .Content property which itself may be stream/bytes/string
	try {
		if ($InputObj -ne $null) {
			# Try common properties
			foreach ($prop in 'Content','RawContent','InnerXml') {
				if ($InputObj.PSObject.Properties.Name -contains $prop) {
					$val = $InputObj.$prop
					if ($val -ne $null) { return Convert-ToString -InputObj $val }
				}
			}
		}
	} catch {}

	# Last resort: ToString()
	try {
		return $InputObj.ToString()
	} catch {
		return $null
	}
}

$ResponseString = $null
$ErrorMessage = $null

try {
	# Try modern Invoke-WebRequest first
	$Result = Invoke-WebRequest -Uri $URL -ErrorAction Stop

	if ($Result -ne $null) {
		# Extract candidate and convert to string
		$Candidate = $null
		if ($Result.PSObject.Properties.Name -contains 'Content') { $Candidate = $Result.Content }
		elseif ($Result.PSObject.Properties.Name -contains 'RawContent') { $Candidate = $Result.RawContent }
		elseif ($Result.PSObject.Properties.Name -contains 'InnerXml') { $Candidate = $Result.InnerXml }
		else { $Candidate = $Result.ToString() }

		$ResponseString = Convert-ToString -InputObj $Candidate
	}
}
catch {
	# If Invoke-WebRequest failed, try fallback
	Write-Verbose "Invoke-WebRequest failed or threw; falling back to System.Net.WebRequest. $_"
	try {
		$Request = [System.Net.WebRequest]::Create($URL)
		$Response = $Request.GetResponse()
		if ($Response -ne $null) {
			$StreamReader = New-Object System.IO.StreamReader $Response.GetResponseStream()
			$ResponseString = $StreamReader.ReadToEnd()
			$StreamReader.Close()
			$Response.Close()
		}
	}
	catch {
		$ErrorMessage = "HTTP request failed: $_"
	}
}

if ($null -eq $ResponseString -and $null -eq $ErrorMessage) {
	$ErrorMessage = "No response received from Duck DNS."
}

# Ensure string type before Trim
if ($ResponseString -isnot [string] -and $ResponseString -ne $null) {
	$ResponseString = Convert-ToString -InputObj $ResponseString
}

if ($ResponseString -ne $null) {
	$ResponseString = $ResponseString.Trim()
}

$Success = $false
$Message = $null

if ($ResponseString -eq "OK") {
	$Success = $true
	$Message = "Update successful."
}
elseif ($ResponseString -eq "KO") {
	$Success = $false
	$Message = "Update failed (Duck DNS returned KO)."
}
elseif ($ErrorMessage) {
	$Success = $false
	$Message = $ErrorMessage
}
else {
	$Success = $false
	$Message = "Unexpected response from Duck DNS: '$ResponseString'"
	Write-Verbose $Message
}

# Build result object (do NOT include the token)
$result = [PSCustomObject]@{
	Timestamp = (Get-Date).ToString("o")
	Domains   = $DomainsString
	IP        = if ($IP) { $IP } else { "" }
	Response  = $ResponseString
	Success   = $Success
	Message   = $Message
}

# Emit the result for automation to consume
Write-Output $result

# Use exit code for automation: 0 = success, 1 = failure
if ($Success) { exit 0 } else { exit 1 }
