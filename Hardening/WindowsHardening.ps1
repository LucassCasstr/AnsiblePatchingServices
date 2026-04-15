# ============================
# WinRM + Kerberos ONLY (AD)
# Restrito por IP
# Execução idempotente
# ============================

$AllowedIP = "192.168.0.1" #SUBSTITUIR PELO IP DO ANSIBLE

# ============================
# Detectar idioma do Windows
# ============================

$UICulture = (Get-UICulture).Name

switch -Wildcard ($UICulture) {
    "pt-*" {
        $WinRMRuleDisplayName = "Gerenciamento Remoto do Windows (HTTP-In)" 
    }
    default {
        $WinRMRuleDisplayName = "Windows Remote Management (HTTP-In)" 
    }
}

$CustomRuleName = "WinRM-HTTP-Restricted-IP"

# ============================
# Habilitar WinRM somente se necessário
# ============================

$winrmService = Get-Service WinRM -ErrorAction SilentlyContinue

if (-not $winrmService -or $winrmService.Status -ne 'Running') {
    Write-Host "WinRM não está ativo. Habilitando PowerShell Remoting..."
    Enable-PSRemoting -Force
} else {
    Write-Host "WinRM já está ativo. Nenhuma ação necessária."
}

# ============================
# Autenticação: Kerberos
# ============================

Set-Item WSMan:\localhost\Service\Auth\Kerberos  -Value $true
Set-Item WSMan:\localhost\Service\Auth\Basic     -Value $false
Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $false

# ============================
# Garantir listener HTTP (5985)
# ============================

if (Get-ChildItem WSMan:\localhost\Listener | Where-Object { $_.Keys -match "Transport=HTTP" }) {
    Write-Host "Listener HTTP já existe."
} else {
    Write-Host "Criando listener HTTP..."
    winrm create winrm/config/Listener?Address=*+Transport=HTTP | Out-Null
}

# ============================
# Firewall – substituir regras WinRM padrão
# ============================

$existingRules = Get-NetFirewallRule -DisplayName $WinRMRuleDisplayName -ErrorAction SilentlyContinue

if ($existingRules) {
    Write-Host "Desabilitando regras WinRM padrão..."
    $existingRules | Disable-NetFirewallRule
}

if (-not (Get-NetFirewallRule -Name $CustomRuleName -ErrorAction SilentlyContinue)) {
    Write-Host "Criando regra WinRM restrita ao IP $AllowedIP..."
    New-NetFirewallRule `
        -Name $CustomRuleName `
        -DisplayName $WinRMRuleDisplayName `
        -Protocol TCP `
        -LocalPort 5985 `
        -Direction Inbound `
        -Action Allow `
        -RemoteAddress $AllowedIP `
        -Profile Domain | Out-Null
} else {
    Write-Host "Regra de firewall restrita já existe."
}

Write-Host "Configuração concluída com sucesso."