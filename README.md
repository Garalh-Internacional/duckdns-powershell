# Update-DuckDNS.ps1

Updates the IP address of your Duck DNS domain(s). Intended to be run as a scheduled task.

## Requirements

- PowerShell 7+ (pwsh) recommended.
- Compatible with Windows PowerShell (5.1). The script uses Invoke-WebRequest when available and falls back to .NET WebRequest if necessary, but PowerShell 3+ / 5.1 or newer is recommended for the best experience.

## Features

- Works in PowerShell 7+ (PowerShell Core) and Windows PowerShell.
- Accepts a comma-separated domains string or an array of domain names.
- Optional IP parameter — if omitted, DuckDNS will detect your gateway IP.
- Uses verbose/debug messages for diagnostics. In scheduled tasks you can capture output to a log file if desired.

## Usage

Basic usage (comma-separated string):
```powershell
.\Update-DuckDNS.ps1 -Domains "foo,bar" -Token my-duck-dns-token
```

Using an array of domains:
```powershell
.\Update-DuckDNS.ps1 -Domains @('foo','bar') -Token my-duck-dns-token
```

Specify an explicit IP:
```powershell
.\Update-DuckDNS.ps1 -Domains "foo" -Token my-duck-dns-token -IP "203.0.113.10"
```

Enable verbose output to see progress:
```powershell
.\Update-DuckDNS.ps1 -Domains "foo" -Token my-duck-dns-token -Verbose
```

## Task Scheduler Instructions

When scheduling the script, prefer pwsh.exe for PowerShell 7+ or powershell.exe for Windows PowerShell.

1. Open Task Scheduler (Win+R → taskschd.msc).
2. Right-click "Task Scheduler Library" and click "Create Basic Task..." or "Create Task..." for advanced options.
3. Name it and set a schedule (for example, Daily).
4. Action: Start a program
   - For PowerShell 7+ (recommended)
     - Program/Script: pwsh.exe
     - Add Arguments: -NoProfile -ExecutionPolicy Bypass -File "C:\Path\To\Update-DuckDNS.ps1" -Domains "foo,bar" -Token my-duck-dns-token
   - For Windows PowerShell
     - Program/Script: powershell.exe
     - Add Arguments: -NoProfile -ExecutionPolicy Bypass -File "C:\Path\To\Update-DuckDNS.ps1" -Domains "foo,bar" -Token my-duck-dns-token
5. (Optional) To capture verbose/debug output to a log file, set the arguments to:
```text
-NoProfile -ExecutionPolicy Bypass -File "C:\Path\To\Update-DuckDNS.ps1" -Domains "foo,bar" -Token my-duck-dns-token -Verbose *> "C:\Path\To\duckdns.log"
```
6. Finish and optionally enable "Run task as soon as possible after a scheduled start is missed" in the task's Settings.

## Testing

1. Login to DuckDNS's site and change your IP to something different (or wait for a change).
2. Right-click the task in Task Scheduler and select "Run".
3. Verify your IP has been updated on the DuckDNS site or by running the script manually with -Verbose to see the "OK" response.

## Notes

- The script returns verbose/debug messages for diagnostics. If DuckDNS returns "OK" the update was successful; "KO" indicates failure and the script will throw an error.
- If you want help adding file-based logging, exit codes for automation, or a ready-made scheduled task XML, open an issue or PR and I can help add that.
