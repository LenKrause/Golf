# bose.ps1
# Configure Bose SA-5 amplifiers for AUX 3 input (3.5mm from Wiim Mini) 

$IP_KitchenOffice = "192.168.86.21"
$IP_BedroomBath   = "192.168.86.250"
$IP_Deck          = "192.168.86.249"

function Set-AUX3($IP) {
  $body = '<ContentItem source="AUX" sourceAccount="AUX3"></ContentItem>'
  Invoke-WebRequest -UseBasicParsing -Method Post -Uri "http://${IP}:8090/select" -ContentType 'application/xml' -Body $body
  # Invoke-WebRequest -Method Post -Uri "http://${IP}:8090/volume" -Body '<Volume>50</Volume>'
}

function Info($IP) {
  [xml]$cmd = (Invoke-WebRequest -UseBasicParsing -Uri "http://${IP}:8090/info").Content
  [xml]$nowPlaying = (Invoke-WebRequest -UseBasicParsing -Uri "http://${IP}:8090/now_playing").Content
  [xml]$volume = (Invoke-WebRequest -UseBasicParsing -Uri "http://${IP}:8090/volume").Content

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

  [pscustomobject]@{
    Name            = $cmd.info.name
    'IP Address'    = $cmd.info.networkInfo[0].ipAddress
    'Serial Number' = $cmd.info.components.component[0].serialNumber
    'Input Source'  = $inputSource
    Volume          = $volume.volume.actualvolume
  } | Format-List
}

function NowPlaying($IP) {
  [xml]$cmd = (Invoke-WebRequest -UseBasicParsing -Uri "http://${IP}:8090/now_playing").Content
  $cmd.nowPlaying | Format-List *
}

function SetVolume($IP, $Volume) {
  Invoke-WebRequest -UseBasicParsing -Method Post -Uri "http://${IP}:8090/volume" -ContentType 'application/xml' -Body "<volume>${Volume}</volume>"
}

function ShowVolume($IP) {
  [xml]$cmd = (Invoke-WebRequest -UseBasicParsing -Uri "http://${IP}:8090/volume").Content
  $cmd.volume.actualvolume
}

$quit = $false
while (-not $quit) {
  Write-Host "`nSelect amplifier:"
  Write-Host "1. Kitchen/Office"
  Write-Host "2. Bedroom/Bath"
  Write-Host "3. Deck"
  Write-Host "---------------------"
  Write-Host "0. Quit"

  $choice = Read-Host "Enter amplifier number"
  switch ($choice) {
    "0" { $quit = $true }
    "1" { $IP = $IP_KitchenOffice }
    "2" { $IP = $IP_BedroomBath }
    "3" { $IP = $IP_Deck }
    default {
      Write-Warning "Invalid amplifier number: $choice. Enter 0, 1, 2, or 3."
      continue
    }
  }

  if ($quit) {
    break
  }

  $changeAmplifier = $false
  while (-not $changeAmplifier -and -not $quit) {
    Write-Host "Choose an action for ${IP}:"
    Write-Host "1. Show device info"
    Write-Host "2. Show now playing"
    Write-Host "3. Show volume"
    Write-Host "4. Set volume"
    Write-Host "5. Select AUX3"
    Write-Host "---------------------"
    Write-Host "0. Select a different amplifier"

    $action = Read-Host "Enter action number"

    switch ($action) {
      "0" { $changeAmplifier = $true }
      "1" { Info $IP }
      "2" { NowPlaying $IP }
      "3" { ShowVolume $IP }
      "4" {
        $volumeText = Read-Host "Enter volume (0-100)"
        $volume = 0
        if (-not [int]::TryParse($volumeText, [ref]$volume) -or $volume -lt 0 -or $volume -gt 100) {
          Write-Warning "Volume must be a whole number from 0 to 100."
        } else {
          SetVolume $IP $volume
        }
      }
      "5" { Set-AUX3 $IP }
      default { Write-Warning "Unknown action: $action" }
    }
  }
}
