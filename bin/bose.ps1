# bose.ps1
# Configure Bose SA-5 amplifiers to set input source, AUX 3 input (3.5mm from Wiim Mini) 

param(
  [Parameter(Position = 0)]
  [ValidateSet("M")]
  [string]$Mode
)

$Amplifiers = @(
  [pscustomobject]@{ Location = "Kitchen/Office"; 'IP Address' = "192.168.86.21"; 'Input Source' = "AUX3" }
  [pscustomobject]@{ Location = "Bedroom/Bath"; 'IP Address' = "192.168.86.250"; 'Input Source' = "AUX3" }
  [pscustomobject]@{ Location = "Deck"; 'IP Address' = "192.168.86.249"; 'Input Source' = "AUX3" }
)

function Test-ConnectionFailure($ErrorRecord) {
  $exception = $ErrorRecord.Exception
  while ($exception) {
    if ($exception -is [System.Net.WebException] -and
        $exception.Status -in @(
          [System.Net.WebExceptionStatus]::ConnectFailure,
          [System.Net.WebExceptionStatus]::Timeout,
          [System.Net.WebExceptionStatus]::ReceiveFailure,
          [System.Net.WebExceptionStatus]::ConnectionClosed,
          [System.Net.WebExceptionStatus]::KeepAliveFailure,
          [System.Net.WebExceptionStatus]::NameResolutionFailure,
          [System.Net.WebExceptionStatus]::ProxyNameResolutionFailure
        )) {
      return $true
    }
    if ($exception -is [System.Net.Sockets.SocketException] -and
        $exception.SocketErrorCode -in @(
          [System.Net.Sockets.SocketError]::ConnectionRefused,
          [System.Net.Sockets.SocketError]::ConnectionReset,
          [System.Net.Sockets.SocketError]::ConnectionAborted,
          [System.Net.Sockets.SocketError]::TimedOut,
          [System.Net.Sockets.SocketError]::HostUnreachable,
          [System.Net.Sockets.SocketError]::HostDown,
          [System.Net.Sockets.SocketError]::NetworkUnreachable,
          [System.Net.Sockets.SocketError]::NetworkDown,
          [System.Net.Sockets.SocketError]::HostNotFound,
          [System.Net.Sockets.SocketError]::TryAgain
        )) {
      return $true
    }
    if ($exception -is [System.TimeoutException] -or
        $exception -is [System.Threading.Tasks.TaskCanceledException]) {
      return $true
    }
    $exception = $exception.InnerException
  }
  return $false
}

function Invoke-AmplifierRequest($Amplifier, $Endpoint, $Method = "Get", $Body) {
  $parameters = @{
    UseBasicParsing = $true
    Uri             = "http://$($Amplifier.'IP Address'):8090/$Endpoint"
    Method          = $Method
    ErrorAction     = "Stop"
  }
  if ($PSBoundParameters.ContainsKey("Body")) {
    $parameters.ContentType = "application/xml"
    $parameters.Body = $Body
  }

  try {
    $response = Invoke-WebRequest @parameters
    return [pscustomobject]@{ Succeeded = $true; Response = $response }
  } catch {
    if (Test-ConnectionFailure $_) {
      Write-Warning "No response from $($Amplifier.Location) ($($Amplifier.'IP Address')). Check that the amplifier is powered on and reachable."
      return [pscustomobject]@{ Succeeded = $false; Response = $null }
    }
    throw
  }
}

function Set-InputSource($Amplifier) {
  $sourceAccount = [System.Security.SecurityElement]::Escape([string]$Amplifier.'Input Source')
  $body = "<ContentItem source=`"AUX`" sourceAccount=`"$sourceAccount`"></ContentItem>"
  $request = Invoke-AmplifierRequest $Amplifier "select" "Post" $body
  if (-not $request.Succeeded) {
    return
  }
  $request.Response
  # Invoke-WebRequest -Method Post -Uri "http://$($Amplifier.'IP Address'):8090/volume" -Body '<Volume>50</Volume>'
}

function Get-InputSource($Amplifier) {
  $request = Invoke-AmplifierRequest $Amplifier "now_playing"
  if (-not $request.Succeeded) {
    return [pscustomobject]@{ Succeeded = $false; Source = $null }
  }
  [xml]$nowPlaying = $request.Response.Content
  $inputSource = $nowPlaying.nowPlaying.GetAttribute("sourceAccount")
  if (-not $inputSource -and $nowPlaying.nowPlaying.ContentItem) {
    $inputSource = $nowPlaying.nowPlaying.ContentItem.GetAttribute("sourceAccount")
  }
  if (-not $inputSource) {
    $inputSource = $nowPlaying.nowPlaying.GetAttribute("source")
  }
  if (-not $inputSource -and $nowPlaying.nowPlaying.ContentItem) {
    $inputSource = $nowPlaying.nowPlaying.ContentItem.GetAttribute("source")
  }
  return [pscustomobject]@{ Succeeded = $true; Source = $inputSource }
}

function Info($Amplifier) {
  $infoRequest = Invoke-AmplifierRequest $Amplifier "info"
  if (-not $infoRequest.Succeeded) {
    return
  }
  $volumeRequest = Invoke-AmplifierRequest $Amplifier "volume"
  if (-not $volumeRequest.Succeeded) {
    return
  }
  $inputSource = Get-InputSource $Amplifier
  if (-not $inputSource.Succeeded) {
    return
  }
  [xml]$cmd = $infoRequest.Response.Content
  [xml]$volume = $volumeRequest.Response.Content

  [pscustomobject]@{
    Location        = $Amplifier.Location
    Name            = $cmd.info.name
    'IP Address'    = $Amplifier.'IP Address'
    'Serial Number' = $cmd.info.components.component[0].serialNumber
    'Input Source'  = $inputSource.Source
    Volume          = $volume.volume.actualvolume
  } | Format-List
}

function NowPlaying($Amplifier) {
  $request = Invoke-AmplifierRequest $Amplifier "now_playing"
  if (-not $request.Succeeded) {
    return
  }
  [xml]$cmd = $request.Response.Content
  $cmd.nowPlaying | Format-List *
}

function SetVolume($Amplifier, $Volume) {
  $request = Invoke-AmplifierRequest $Amplifier "volume" "Post" "<volume>${Volume}</volume>"
  if (-not $request.Succeeded) {
    return
  }
  $request.Response
}

function ShowVolume($Amplifier) {
  $request = Invoke-AmplifierRequest $Amplifier "volume"
  if (-not $request.Succeeded) {
    return
  }
  [xml]$cmd = $request.Response.Content
  $cmd.volume.actualvolume
}

function MonitorInputSource {
  Write-Host "Monitoring all amplifiers and restoring their configured input sources. Press Ctrl+C to stop."
  while ($true) {
    foreach ($amplifier in $Amplifiers) {
      try {
        $inputSource = Get-InputSource $amplifier
        if (-not $inputSource.Succeeded) {
          continue
        }
        if (-not [string]::Equals($inputSource.Source, $amplifier.'Input Source', [System.StringComparison]::OrdinalIgnoreCase)) {
          $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
          Write-Host "[$timestamp] $($amplifier.Location): input is '$($inputSource.Source)'; selecting $($amplifier.'Input Source')."
          Set-InputSource $amplifier | Out-Null
        }
      } catch {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Warning "[$timestamp] $($amplifier.Location) ($($amplifier.'IP Address')): monitor failed: $($_.Exception.Message)"
      }
    }
    Start-Sleep -Seconds 15
  }
}

function ConvertTo-IPv4Number($Address) {
  [uint64]$number = 0
  foreach ($byte in $Address.GetAddressBytes()) {
    $number = ($number * 256) + [uint64]$byte
  }
  return $number
}

function ConvertFrom-IPv4Number([uint64]$Number) {
  $octets = @()
  for ($shift = 24; $shift -ge 0; $shift -= 8) {
    $octets += [int](($Number -shr $shift) -band 255)
  }
  return $octets -join "."
}

function Get-LocalIPv4Subnets {
  $subnets = @()
  foreach ($networkInterface in [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
    if ($networkInterface.OperationalStatus -ne [System.Net.NetworkInformation.OperationalStatus]::Up -or
        $networkInterface.NetworkInterfaceType -eq [System.Net.NetworkInformation.NetworkInterfaceType]::Loopback) {
      continue
    }

    foreach ($unicastAddress in $networkInterface.GetIPProperties().UnicastAddresses) {
      $address = $unicastAddress.Address
      $mask = $unicastAddress.IPv4Mask
      if ($address.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork -or -not $mask) {
        continue
      }

      $octets = $address.GetAddressBytes()
      $isPrivate = $octets[0] -eq 10 -or
        ($octets[0] -eq 172 -and $octets[1] -ge 16 -and $octets[1] -le 31) -or
        ($octets[0] -eq 192 -and $octets[1] -eq 168)
      if (-not $isPrivate) {
        continue
      }

      $prefixLength = 0
      $maskHasZero = $false
      $validMask = $true
      foreach ($byte in $mask.GetAddressBytes()) {
        for ($bit = 7; $bit -ge 0; $bit--) {
          if ($byte -band (1 -shl $bit)) {
            if ($maskHasZero) {
              $validMask = $false
            }
            $prefixLength++
          } else {
            $maskHasZero = $true
          }
        }
      }
      if (-not $validMask) {
        continue
      }

      [uint64]$maskNumber = ConvertTo-IPv4Number $mask
      [uint64]$addressNumber = ConvertTo-IPv4Number $address
      [uint64]$networkNumber = $addressNumber -band $maskNumber
      [uint64]$broadcastNumber = $networkNumber -bor ([uint64]4294967295 -bxor $maskNumber)
      $hostCount = $broadcastNumber - $networkNumber - 1
      if ($hostCount -lt 1) {
        continue
      }

      $subnets += [pscustomobject]@{
        InterfaceName = $networkInterface.Name
        Address       = $address.IPAddressToString
        AddressNumber = $addressNumber
        Network       = (ConvertFrom-IPv4Number $networkNumber)
        NetworkNumber = $networkNumber
        BroadcastNumber = $broadcastNumber
        PrefixLength  = $prefixLength
        HostCount     = $hostCount
      }
    }
  }
  return $subnets
}

function Test-TcpPorts([string[]]$IPAddresses, [int]$Port, [int]$TimeoutMilliseconds) {
  $respondingAddresses = @()
  for ($offset = 0; $offset -lt $IPAddresses.Count; $offset += 32) {
    $entries = @()
    $lastIndex = [Math]::Min($offset + 31, $IPAddresses.Count - 1)
    for ($i = $offset; $i -le $lastIndex; $i++) {
      $client = New-Object System.Net.Sockets.TcpClient
      try {
        $connection = $client.BeginConnect($IPAddresses[$i], $Port, $null, $null)
        $entries += [pscustomobject]@{
          IPAddress  = $IPAddresses[$i]
          Client     = $client
          Connection = $connection
        }
      } catch [System.Net.Sockets.SocketException] {
        $client.Close()
      }
    }

    if ($entries.Count -eq 0) {
      continue
    }
    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    foreach ($entry in $entries) {
      $remainingMilliseconds = [int]($deadline - [DateTime]::UtcNow).TotalMilliseconds
      if ($remainingMilliseconds -lt 0) {
        $remainingMilliseconds = 0
      }
      $entry.Connection.AsyncWaitHandle.WaitOne($remainingMilliseconds) | Out-Null
    }
    foreach ($entry in $entries) {
      try {
        if ($entry.Connection.AsyncWaitHandle.WaitOne(0)) {
          $entry.Client.EndConnect($entry.Connection)
          $respondingAddresses += $entry.IPAddress
        }
      } catch [System.Net.Sockets.SocketException] {
      } finally {
        $entry.Client.Close()
        $entry.Connection.AsyncWaitHandle.Close()
      }
    }
  }
  return $respondingAddresses
}

function Find-Amplifiers {
  $subnets = @(Get-LocalIPv4Subnets)
  if ($subnets.Count -eq 0) {
    Write-Warning "No active private IPv4 network interfaces were found."
    return
  }

  if ($subnets.Count -eq 1) {
    $subnet = $subnets[0]
  } else {
    Write-Host "`nSelect the local network to search:"
    for ($i = 0; $i -lt $subnets.Count; $i++) {
      Write-Host "$($i + 1). $($subnets[$i].InterfaceName): $($subnets[$i].Address) ($($subnets[$i].Network)/$($subnets[$i].PrefixLength))"
    }
    Write-Host "0. Cancel"
    $networkChoice = Read-Host "Enter network number"
    if ($networkChoice -eq "0") {
      return
    }
    $networkSelection = 0
    if (-not [int]::TryParse($networkChoice, [ref]$networkSelection) -or
        $networkSelection -lt 1 -or $networkSelection -gt $subnets.Count) {
      Write-Warning "Invalid network selection: $networkChoice."
      return
    }
    $subnet = $subnets[$networkSelection - 1]
  }

  $scanNetworkNumber = $subnet.NetworkNumber
  $scanBroadcastNumber = $subnet.BroadcastNumber
  $scanNetwork = $subnet.Network
  $scanPrefixLength = $subnet.PrefixLength
  if ($subnet.HostCount -gt 254) {
    Write-Warning "The selected subnet contains $($subnet.HostCount) host addresses. Searching 254 hosts using a /24 (Class C) range."
    [uint64]$classCNetworkMask = 4294967040
    [uint64]$scanNetworkNumber = $subnet.AddressNumber -band $classCNetworkMask
    [uint64]$scanBroadcastNumber = $scanNetworkNumber -bor [uint64]255
    $scanNetwork = ConvertFrom-IPv4Number $scanNetworkNumber
    $scanPrefixLength = 24
  }

  Write-Host "Searching $scanNetwork/$scanPrefixLength on $($subnet.InterfaceName) for TCP port 8090..."
  $knownAddresses = @($script:Amplifiers | ForEach-Object { $_.'IP Address' })
  $localAddresses = @($subnets | ForEach-Object { $_.Address })
  $candidateAddresses = @()
  for ([uint64]$candidate = $scanNetworkNumber + 1; $candidate -lt $scanBroadcastNumber; $candidate++) {
    $ipAddress = ConvertFrom-IPv4Number $candidate
    if ($knownAddresses -contains $ipAddress -or $localAddresses -contains $ipAddress) {
      continue
    }
    $candidateAddresses += $ipAddress
  }
  $foundAddresses = @(Test-TcpPorts $candidateAddresses 8090 300)
  foreach ($ipAddress in $foundAddresses) {
    Write-Host "Found TCP port 8090 at $ipAddress."
  }

  if ($foundAddresses.Count -eq 0) {
    Write-Host "No new devices responding on TCP port 8090 were found."
    return
  }

  foreach ($ipAddress in $foundAddresses) {
    $location = Read-Host "Location for $ipAddress (leave blank to skip)"
    if ([string]::IsNullOrWhiteSpace($location)) {
      Write-Host "Skipped $ipAddress."
      continue
    }
    $script:Amplifiers += [pscustomobject]@{
      Location         = $location.Trim()
      'IP Address'     = $ipAddress
      'Input Source'   = "AUX3"
    }
    Write-Host "Added $($location.Trim()) ($ipAddress)."
  }
}

$quit = $false
if ($Mode -eq "M") {
  MonitorInputSource
} else {
  while (-not $quit) {
    Write-Host "`nSelect amplifier:"
    for ($i = 0; $i -lt $Amplifiers.Count; $i++) {
      Write-Host "$($i + 1). $($Amplifiers[$i].Location)"
    }
    Write-Host "M. Monitor all amplifiers and restore configured input sources"
    Write-Host "S. Search local network for amplifiers"
    Write-Host "---------------------"
    Write-Host "0. Quit"

    $choice = Read-Host "Enter amplifier number, M, or S"
    switch ($choice) {
      "0" { $quit = $true }
      "M" { MonitorInputSource }
      "S" { Find-Amplifiers }
      default {
        $selection = 0
        if (-not [int]::TryParse($choice, [ref]$selection) -or $selection -lt 1 -or $selection -gt $Amplifiers.Count) {
          Write-Warning "Invalid selection: $choice. Enter a number from 1 to $($Amplifiers.Count), 0, M, or S."
          continue
        }
      }
    }

    if ($quit) {
      break
    }

    if ($choice -eq "M") {
      continue
    }
    if ($choice -eq "S") {
      continue
    }

    $amplifier = $Amplifiers[$selection - 1]
    $changeAmplifier = $false
    while (-not $changeAmplifier -and -not $quit) {
      Write-Host "`nChoose an action for $($amplifier.Location) ($($amplifier.'IP Address')):"
      Write-Host "1. Show device info"
      Write-Host "2. Show now playing"
      Write-Host "3. Show volume"
      Write-Host "4. Set volume"
      Write-Host "5. Select configured input ($($amplifier.'Input Source'))"
      Write-Host "---------------------"
      Write-Host "0. Select a different amplifier"

      $action = Read-Host "Enter action number"

      switch ($action) {
        "0" { $changeAmplifier = $true }
        "1" { Info $amplifier }
        "2" { NowPlaying $amplifier }
        "3" { ShowVolume $amplifier }
        "4" {
          $volumeText = Read-Host "Enter volume (0-100)"
          $volume = 0
          if (-not [int]::TryParse($volumeText, [ref]$volume) -or $volume -lt 0 -or $volume -gt 100) {
            Write-Warning "Volume must be a whole number from 0 to 100."
          } else {
            SetVolume $amplifier $volume
          }
        }
        "5" { Set-InputSource $amplifier }
        default { Write-Warning "Unknown action: $action" }
      }
    }
  }
}
