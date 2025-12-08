# Updated for PowerShell 7 compatibility
# Original: https://github.com/ataylor32/duckdns-powershell
<#
.SYNOPSIS
	Updates the IP address of your Duck DNS domain(s).
.DESCRIPTION
	Updates the IP address of your Duck DNS domain(s). Intended to be run as a
	scheduled task. This version is compatible with PowerShell 7+ and Windows
	PowerShell.
.PARAMETER Domains
	A comma-separated list (or array) of your Duck DNS domains to update.
.PARAMETER Token
	Your Duck DNS token.
.PARAMETER IP
	The IP address to use. If you leave it blank, Duck DNS will detect your
	gateway IP.
.INPUTS
	None. You cannot pipe objects to this script.
.OUTPUTS
	None. This script does not generate any output by default.
.EXAMPLE
	.\Update-DuckDNS.ps1 -Domains "foo,bar" -Token my-duck-dns-token
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

# Normalise domains to a single comma-separated string (accepts array or single string)
if ($Domains -is [System.Array]) {
	$DomainsString = ($Domains -join ',').Trim()
} else {
	$DomainsString = $Domains.Trim()
}

# Build URL (IP may be empty)
$URL = "https://www.duckdns.org/update?domains={0}&token={1}&ip={2}" -f [uri]::EscapeDataString($DomainsString), [uri]::EscapeDataString($Token), [uri]::EscapeDataString($IP)

Write-Debug "`$URL set to $URL"
Write-Verbose "Sending update request to Duck DNS..."

$ResponseString = $null

try {
	# Preferred modern approach: Invoke-WebRequest works in PowerShell 3+ including PowerShell 7.
	$Result = Invoke-WebRequest -Uri $URL -UseBasicParsing:$false -ErrorAction Stop

	# Try several ways to extract the response body/content for compatibility across versions
	$ResponseString = $null

	# If object has Content property (PowerShell Core / modern PS), use it
	if ($Result -ne $null) {
		# Expand Content if available
		$Content = $null
		try { $Content = $Result.Content } catch { $Content = $null }
		if ([string]::IsNullOrEmpty($Content)) {
			# Fallback to using the RawContent, innerxml, or ToString()
			# RawContent is available on some platforms; use whichever is present
			if ($Result -is [string]) {
				$ResponseString = $Result
			} else {
				$ResponseString = ($Result.RawContent -as [string]) -or ($Result.InnerXml -as [string]) -or ($Result.ToString())
			}
		} else {
			$ResponseString = $Content
		}
	}
}
catch [System.Net.WebException] {
	# If Invoke-WebRequest failed (older environments), fall back to System.Net.WebRequest
	Write-Verbose "Invoke-WebRequest failed, falling back to System.Net.WebRequest. $_"
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
		throw "HTTP request failed: $_"
	}
}
catch {
	throw "HTTP request failed: $_"
}

if ($null -eq $ResponseString) {
	throw "No response received from Duck DNS."
}

# Trim whitespace/newlines and normalise
$ResponseString = $ResponseString.Trim()

if ($ResponseString -eq "OK") {
	Write-Verbose "Update successful."
}
elseif ($ResponseString -eq "KO") {
	throw "Update failed (Duck DNS returned KO)."
}
else {
	# Some responses may include other text (or multiple lines); include it in the message for debugging
	Write-Verbose "Unexpected response from Duck DNS: '$ResponseString'"
}
