# Before running this PowerShell script, remember to install MicrosoftPowerBIMgmt with the following command: 
# Install-Module -Name MicrosoftPowerBIMgmt -Scope CurrentUser -AllowClobber -Force

# Clear the console for a clean interactive experience
Clear-Host
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "   Semantic Model Takeover Management Suite    " -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Helper: Invoke-PowerBIRestMethod wrapper with automatic retry/backoff on
# HTTP 429 (throttling) responses. All REST calls in this script should go
# through this wrapper instead of calling Invoke-PowerBIRestMethod directly.
# ---------------------------------------------------------------------------
function Invoke-PowerBIRestMethodWithRetry {
    param(
        [Parameter(Mandatory)] [string]$Url,
        [string]$Method = "Get",
        [string]$Body = $null,
        [int]$MaxRetries = 5
    )

    $attempt = 0
    while ($true) {
        try {
            if ($null -ne $Body) {
                return Invoke-PowerBIRestMethod -Url $Url -Method $Method -Body $Body -ErrorAction Stop
            } else {
                return Invoke-PowerBIRestMethod -Url $Url -Method $Method -ErrorAction Stop
            }
        }
        catch {
            $attempt++
            $statusCode = $null
            try {
                if ($_.Exception.Response) {
                    $statusCode = [int]$_.Exception.Response.StatusCode
                }
            } catch { }

            $isThrottled = ($statusCode -eq 429) -or ($_.Exception.Message -match '429|TooManyRequests|throttl')

            if ($isThrottled -and $attempt -le $MaxRetries) {
                $retryAfter = $null
                try {
                    if ($_.Exception.Response -and $_.Exception.Response.Headers -and $_.Exception.Response.Headers['Retry-After']) {
                        $retryAfter = [int]$_.Exception.Response.Headers['Retry-After']
                    }
                } catch { }

                if (-not $retryAfter) {
                    $retryAfter = [Math]::Min(60, [Math]::Pow(2, $attempt))
                }

                Write-Host "  [THROTTLED] Rate limit hit calling '$Url'. Waiting $retryAfter second(s) before retry ($attempt/$MaxRetries)..." -ForegroundColor DarkYellow
                Start-Sleep -Seconds $retryAfter
                continue
            }
            else {
                throw
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Helper: Follows @odata.nextLink pagination for any Power BI "list" endpoint
# (e.g. groups, groups/{id}/datasets) and returns the fully aggregated set of
# items across all pages.
# ---------------------------------------------------------------------------
function Get-PowerBIAllPages {
    param(
        [Parameter(Mandatory)] [string]$InitialUrl
    )

    $baseUri = "https://api.powerbi.com/v1.0/myorg/"
    $results = [System.Collections.Generic.List[object]]::new()
    $nextUrl = $InitialUrl

    while ($nextUrl) {
        $raw = Invoke-PowerBIRestMethodWithRetry -Url $nextUrl -Method Get
        $parsed = $raw | ConvertFrom-Json

        if ($parsed.value) {
            foreach ($item in $parsed.value) {
                $results.Add($item)
            }
        }

        if ($parsed.'@odata.nextLink') {
            $full = $parsed.'@odata.nextLink'
            if ($full.StartsWith($baseUri)) {
                $nextUrl = $full.Substring($baseUri.Length)
            } else {
                $nextUrl = $full
            }
        } else {
            $nextUrl = $null
        }
    }

    return $results
}

# ---------------------------------------------------------------------------
# Helper: Single, shared implementation of the takeover REST call. Used by
# both the global (9999) takeover path and the per-workspace takeover path so
# the logic (and any future changes, e.g. additional logging) lives in one
# place instead of two.
# ---------------------------------------------------------------------------
function Invoke-DatasetTakeover {
    param(
        [Parameter(Mandatory)] $Model
    )

    Write-Host "Processing takeover for: $($Model.ModelName) inside [$($Model.WorkspaceName)]" -ForegroundColor Cyan
    try {
        Invoke-PowerBIRestMethodWithRetry -Url "groups/$($Model.WorkspaceId)/datasets/$($Model.ModelId)/Default.TakeOver" -Method Post -Body "" | Out-Null
        Write-Host "  -> SUCCESS" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "  -> FAILED: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

Write-Host "`n[Step 1] Authenticating Service Principal" -ForegroundColor Yellow

# Interactive Prompts for Credentials
$tenantId     = Read-Host "Enter your Tenant ID"
$clientId     = Read-Host "Enter your Client ID (Application ID)"
$clientSecret = Read-Host "Enter your Client Secret" -AsSecureString

# Create the credential object
$credential = New-Object System.Management.Automation.PSCredential ($clientId, $clientSecret)

# Attempt Login
try {
    Write-Host "Connecting to Power BI Service..." -ForegroundColor Yellow
    Connect-PowerBIServiceAccount -ServicePrincipal -Tenant $tenantId -Credential $credential -ErrorAction Stop | Out-Null
    Write-Host "Login Successful!" -ForegroundColor Green
    
    # Extract the local Object ID (oid) of the Service Principal from token claims
    # Used to determine ownership of semantic models in the environment for service principal users
    $oid = $null
    $tokenClaims = $null
    try {
        $tokenObj = Get-PowerBIAccessToken
        $tokenStr = $null

        if ($null -ne $tokenObj) {
            if ($tokenObj -is [string]) { $tokenStr = $tokenObj }
            elseif ($tokenObj.AccessToken) { $tokenStr = $tokenObj.AccessToken }
            elseif ($tokenObj.Authorization) { $tokenStr = $tokenObj.Authorization -replace '^Bearer\s+', '' }
            else { $tokenStr = $tokenObj.ToString() }
        }

        if ($tokenStr -and $tokenStr.Contains('.')) {
            $jwtParts = $tokenStr.Split('.')
            if ($jwtParts.Count -ge 2) {
                $payload = $jwtParts[1].Replace('-', '+').Replace('_', '/')
                $padLength = 4 - ($payload.Length % 4)
                if ($padLength -lt 4) { $payload += "=" * $padLength }
                
                $decodedBytes = [System.Convert]::FromBase64String($payload)
                $decodedText  = [System.Text.Encoding]::UTF8.GetString($decodedBytes)
                $tokenClaims  = $decodedText | ConvertFrom-Json
                
                if ($tokenClaims.oid) { $oid = $tokenClaims.oid }
                elseif ($tokenClaims.sub) { $oid = $tokenClaims.sub }
            }
        }
        
        if ($null -eq $oid) {
            Write-Host "[WARNING] Logged in, but 'oid' could not be resolved from token." -ForegroundColor Yellow
            $oid = "UNKNOWN_OID"
        } else {
            Write-Host "Principal OID Resolved: $oid" -ForegroundColor Green
        }
    } catch {
        Write-Host "[WARNING] Token parsing skipped: $($_.Exception.Message)" -ForegroundColor Yellow
        $oid = "UNKNOWN_OID"
    }
}
catch {
    Write-Host "CRITICAL ERROR: Failed to log in." -ForegroundColor Red
    if ($_.Exception -and $_.Exception.InnerException) { Write-Host "Details: $($_.Exception.InnerException.Message)" -ForegroundColor Red }
    # NOTE: 'Break' is only valid inside a loop/switch. At this point in the
    # script no loop has started yet, so we exit the script directly instead.
    exit 1
}

# Resolve a friendly display name if present in token claims, otherwise use Client ID
$spDisplayName = if ($tokenClaims -and $tokenClaims.name) { $tokenClaims.name } else { $clientId }

# Initialize data persistence caches and refresh control flag
$needsRefresh = $true
$workspaceInventory = [System.Collections.Generic.List[object]]::new()
$globalModelCache = [System.Collections.Generic.List[object]]::new()

# Dynamic Main Application Interface Loop
while ($true) {
    
    # Only pull data from Fabric APIs if a state change occurred (e.g., after a takeover execution or manual refresh)
    if ($needsRefresh) {
        Write-Host "`n-----------------------------------------------" -ForegroundColor Cyan
        Write-Host "Scanning Power BI Environment (Refreshing Data)..." -ForegroundColor Yellow
        
        try {
            $workspaces = Get-PowerBIAllPages -InitialUrl "groups" | Sort-Object name
        }
        catch {
            Write-Host "CRITICAL ERROR: Failed to retrieve workspaces." -ForegroundColor Red
            Break
        }

        if ($null -eq $workspaces -or $workspaces.Count -eq 0) {
            Write-Host "No accessible workspaces found for this Service Principal." -ForegroundColor Red
            Break
        }

        # Clear active session collections for the updated pull
        $workspaceInventory = [System.Collections.Generic.List[object]]::new()
        $globalModelCache = [System.Collections.Generic.List[object]]::new()
        $skippedWorkspaces = [System.Collections.Generic.List[object]]::new()

        foreach ($ws in $workspaces) {
            $totalModels = 0
            $ownedModels = 0
            
            try {
                $datasets = Get-PowerBIAllPages -InitialUrl "groups/$($ws.id)/datasets"
                
                foreach ($ds in $datasets) {
                    $totalModels++
                    $isOwnerMatch = $false
                    if ($null -ne $ds.configuredBy -and $ds.configuredBy -eq $oid) {
                        $isOwnerMatch = $true
                        $ownedModels++
                    }

                    $globalModelCache.Add([PSCustomObject]@{
                        WorkspaceId   = $ws.id
                        WorkspaceName = $ws.name
                        ModelName     = $ds.name
                        ModelId       = $ds.id
                        ModelOwner    = if ($ds.configuredBy) { $ds.configuredBy } else { "Unowned / Orphaned" }
                        CurrentSP_OID = $oid
                        IsOwner       = $isOwnerMatch
                    })
                }
            } catch {
                # Workspace access failed (e.g. restricted permissions, deleted workspace,
                # or a non-throttling API error). Record it instead of failing silently so
                # the operator knows the inventory below may be incomplete.
                $skippedWorkspaces.Add([PSCustomObject]@{
                    WorkspaceName = $ws.name
                    WorkspaceId   = $ws.id
                    Reason        = $_.Exception.Message
                })
                Write-Host "  [SKIPPED] Could not read datasets for workspace '$($ws.name)': $($_.Exception.Message)" -ForegroundColor DarkYellow
            }

            $workspaceInventory.Add([PSCustomObject]@{
                WorkspaceId   = $ws.id
                WorkspaceName = $ws.name
                TotalModels   = $totalModels
                OwnedModels   = $ownedModels
            })
        }

        if ($skippedWorkspaces.Count -gt 0) {
            Write-Host "`n[WARNING] $($skippedWorkspaces.Count) workspace(s) could not be scanned and are NOT reflected below:" -ForegroundColor Yellow
            foreach ($skipped in $skippedWorkspaces) {
                Write-Host "  - $($skipped.WorkspaceName) ($($skipped.WorkspaceId)): $($skipped.Reason)" -ForegroundColor DarkYellow
            }
        }
        
        # Reset flag; subsequent navigation loops back instantly using localized persistent cache
        $needsRefresh = $false
    }

    # Render Main Workspace Overview Screen
    Write-Host "`n========================= WORKSPACE OVERVIEW =========================" -ForegroundColor Green
    Write-Host "Logged-in User : $spDisplayName" -ForegroundColor White
    Write-Host "User Object ID : $oid" -ForegroundColor White
    Write-Host "Format         : [Index] Workspace Name (Owned Models / Total Models)" -ForegroundColor Gray
    Write-Host "--------------------------------------------------------------------" -ForegroundColor Gray

    for ($i = 0; $i -lt $workspaceInventory.Count; $i++) {
        $wsItem = $workspaceInventory[$i]
        $displayIndex = $i + 1
        
        # Determine strict row styling rule
        if ($wsItem.TotalModels -gt 0 -and $wsItem.OwnedModels -eq $wsItem.TotalModels) {
            # Fully owned workspace completely lights up green (Index, Name, metrics)
            Write-Host "[$displayIndex] $($wsItem.WorkspaceName.PadRight(40)) (Owned: $($wsItem.OwnedModels) / Total: $($wsItem.TotalModels))" -ForegroundColor Green
        }
        elseif ($wsItem.TotalModels -eq 0) {
            # Empty workspaces display cleanly as dark gray
            Write-Host "[$displayIndex] " -NoNewline -ForegroundColor Cyan
            Write-Host "$($wsItem.WorkspaceName.PadRight(40)) (Owned: 0 / Total: 0)" -ForegroundColor DarkGray
        }
        else {
            # Partially owned or unowned workspaces split highlight colors for visibility
            Write-Host "[$displayIndex] " -NoNewline -ForegroundColor Cyan
            Write-Host "$($wsItem.WorkspaceName.PadRight(40)) " -NoNewline -ForegroundColor White
            Write-Host "(Owned: $($wsItem.OwnedModels) / Total: $($wsItem.TotalModels))" -ForegroundColor Yellow
        }
    }

    Write-Host "--------------------------------------------------------------------" -ForegroundColor Gray
    Write-Host "[r]    MANUALLY REFRESH WORKSPACE DATA" -ForegroundColor Yellow
    Write-Host "[9999] OVERTAKE ALL SEMANTIC MODELS ACROSS ALL WORKSPACES" -ForegroundColor DarkRed
    Write-Host "[exit] Exit target environment script" -ForegroundColor Gray
    Write-Host "====================================================================" -ForegroundColor Green

    # Process Menu Input
    $selection = Read-Host "`nEnter a workspace selection index, 'r' to refresh, 9999, or exit"
    $selection = $selection.Trim()

    if ($selection -eq "exit") {
        Write-Host "Exiting environment test suite. Goodbye!" -ForegroundColor Cyan
        Break
    }

    # Option r: Manual Rescan / Refresh
    if ($selection -eq "r") {
        $needsRefresh = $true
        continue
    }

    # Option 9999: Global High-Security Takeover Run
    if ($selection -eq "9999") {
        $unownedGlobalModels = $globalModelCache | Where-Object { $_.IsOwner -eq $false }
        
        if ($unownedGlobalModels.Count -eq 0) {
            Write-Host "`n[SKIPPED] The Service Principal already owns 100% of discovered models globally." -ForegroundColor Green
            Read-Host "Press Enter to return to overview..."
            continue
        }

        Write-Host "`n!!! WARNING: Initiating Global Takeover of $($unownedGlobalModels.Count) model(s) !!!" -ForegroundColor Red
        $confirm = Read-Host "Type 'CONFIRM' to execute global operational takeover"
        if ($confirm -ne "CONFIRM") {
            Write-Host "Global takeover aborted by user safety control." -ForegroundColor Yellow
            Read-Host "Press Enter to return to overview..."
            continue
        }

        foreach ($model in $unownedGlobalModels) {
            Invoke-DatasetTakeover -Model $model | Out-Null
        }
        
        # Trigger an environment rescan since models have changed globally
        $needsRefresh = $true
        Read-Host "`nGlobal operation complete. Press Enter to refresh workspace status maps..."
        continue
    }

    # Workspace Specific Depth Selection Check
    if ($selection -match '^\d+$') {
        $targetIdx = [int]$selection - 1
        if ($targetIdx -ge 0 -and $targetIdx -lt $workspaceInventory.Count) {
            $selectedWS = $workspaceInventory[$targetIdx]
            
            # Workspace Sub-Menu Context Window Loop
            while ($true) {
                Clear-Host
                Write-Host "====================================================================" -ForegroundColor Cyan
                Write-Host " WORKSPACE DETAIL VIEW: $($selectedWS.WorkspaceName)" -ForegroundColor White
                Write-Host " ID: $($selectedWS.WorkspaceId)" -ForegroundColor Gray
                Write-Host "====================================================================" -ForegroundColor Cyan
                
                # Filter cached semantic models to match only the selected workspace
                $localModels = @($globalModelCache | Where-Object { $_.WorkspaceId -eq $selectedWS.WorkspaceId })

                if ($localModels.Count -eq 0) {
                    Write-Host "`nNo semantic models exist inside this workspace." -ForegroundColor Yellow
                    Write-Host "--------------------------------------------------------------------" -ForegroundColor Cyan
                    Write-Host "[back] Return to Global Workspace Overview" -ForegroundColor Green
                    Write-Host "[r]    Refresh Workspace Data" -ForegroundColor Yellow
                    Write-Host "--------------------------------------------------------------------" -ForegroundColor Cyan
                } else {
                    Write-Host "Format: [Index] Model Name | Owner OID | IsOwner" -ForegroundColor Gray
                    Write-Host "--------------------------------------------------------------------" -ForegroundColor Gray
                    
                    # Numbered display layout of all local models (Entire name matches ownership color)
                    for ($m = 0; $m -lt $localModels.Count; $m++) {
                        $model = $localModels[$m]
                        $mIdx = $m + 1
                        
                        Write-Host "[$mIdx] " -NoNewline -ForegroundColor Cyan
                        
                        # Dynamic ownership color scheme applied to the Model Name
                        if ($model.IsOwner) {
                            Write-Host "$($model.ModelName.PadRight(30))" -NoNewline -ForegroundColor Green
                        } else {
                            Write-Host "$($model.ModelName.PadRight(30))" -NoNewline -ForegroundColor Red
                        }
                        
                        Write-Host " | $($model.ModelOwner) | IsOwner: " -NoNewline -ForegroundColor Gray
                        
                        if ($model.IsOwner) {
                            Write-Host "True" -ForegroundColor Green
                        } else {
                            Write-Host "False" -ForegroundColor Red
                        }
                    }

                    Write-Host "--------------------------------------------------------------------" -ForegroundColor Cyan
                    Write-Host "[9999] Take Over ALL semantic models inside this workspace" -ForegroundColor Red
                    Write-Host "[r]    Refresh Workspace Data" -ForegroundColor Yellow
                    Write-Host "[back] Return to Global Workspace Overview" -ForegroundColor Green
                    Write-Host "--------------------------------------------------------------------" -ForegroundColor Cyan
                }
                
                $subSelection = Read-Host "Select model index/indices to TAKE OWNERSHIP (e.g. 1, 1,3, 2-4), 9999, 'r', or 'back'"
                $subSelection = $subSelection.Trim()

                if ($subSelection -eq "back" -or $subSelection -eq "b") {
                    break
                }

                if ($subSelection -eq "r") {
                    $needsRefresh = $true
                    break # Break back to global loop to execute refresh cycle
                }

                # Parse operational target selections
                $targetModels = [System.Collections.Generic.List[object]]::new()
                if ($subSelection -eq "9999") {
                    foreach ($m in $localModels) { $targetModels.Add($m) }
                } else {
                    # Handle multiple selections (individual indices, lists, and ranges)
                    $parts = $subSelection -split ','
                    $selectedIndices = [System.Collections.Generic.List[int]]::new()
                    foreach ($part in $parts) {
                        $part = $part.Trim()
                        if ($part -match '^\d+$') {
                            $idx = [int]$part - 1
                            if ($idx -ge 0 -and $idx -lt $localModels.Count) {
                                $selectedIndices.Add($idx)
                            }
                        } elseif ($part -match '^(\d+)\s*-\s*(\d+)$') {
                            $start = [int]$Matches[1] - 1
                            $end = [int]$Matches[2] - 1
                            $step = if ($start -le $end) { 1 } else { -1 }
                            for ($i = $start; $i -ne ($end + $step); $i += $step) {
                                if ($i -ge 0 -and $i -lt $localModels.Count) {
                                    $selectedIndices.Add($i)
                                }
                            }
                        }
                    }
                    
                    # Deduplicate indices and build target set
                    $uniqueIndices = $selectedIndices | Select-Object -Unique
                    foreach ($idx in $uniqueIndices) {
                        $targetModels.Add($localModels[$idx])
                    }
                }

                if ($targetModels.Count -gt 0) {
                    # Isolate models currently unowned to prevent redundant API calls
                    $unownedLocalTargets = @($targetModels | Where-Object { $_.IsOwner -eq $false })
                    $alreadyOwnedCount = $targetModels.Count - $unownedLocalTargets.Count

                    if ($alreadyOwnedCount -gt 0) {
                        Write-Host "`nNote: $alreadyOwnedCount selected model(s) are already owned by you." -ForegroundColor Yellow
                    }

                    if ($unownedLocalTargets.Count -eq 0) {
                        Write-Host "All selected models are already owned. No action needed." -ForegroundColor Green
                        Read-Host "Press Enter to continue..."
                        continue
                    }

                    # Explicit Confirmation Safeguard Step
                    Write-Host "`n------------------------------------------------------------" -ForegroundColor Yellow
                    Write-Host "CONFIRMATION REQUIRED:" -ForegroundColor Yellow
                    Write-Host "You are about to TAKE OWNERSHIP of the following $($unownedLocalTargets.Count) model(s):" -ForegroundColor White
                    foreach ($mTarget in $unownedLocalTargets) {
                        Write-Host "  * $($mTarget.ModelName)" -ForegroundColor Red
                    }
                    Write-Host "------------------------------------------------------------" -ForegroundColor Yellow
                    
                    $confirmTakeover = Read-Host "Proceed with taking ownership? (Y / N)"
                    if ($confirmTakeover.Trim().ToUpper() -notin @("Y", "YES")) {
                        Write-Host "`nTakeover operation cancelled by user." -ForegroundColor Yellow
                        Read-Host "Press Enter to continue..."
                        continue
                    }

                    Write-Host "`nExecuting targeted takeover sequence..." -ForegroundColor Yellow
                    foreach ($model in $unownedLocalTargets) {
                        Invoke-DatasetTakeover -Model $model | Out-Null
                    }
                    
                    # Flag refresh as true because state changes occurred
                    $needsRefresh = $true
                    Read-Host "`nWorkspace takeover run complete. Press Enter to refresh metrics..."
                    break 
                } else {
                    Write-Host "Invalid target selection, format configuration, or bounds range." -ForegroundColor Red
                    Start-Sleep -Seconds 1.5
                }
            }
        } else {
            Write-Host "Selection index out of directory bounds." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    } else {
        Write-Host "Input configuration unrecognizable." -ForegroundColor Red
        Start-Sleep -Seconds 1
    }
}