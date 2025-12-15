# Script para sincronizar arquivos do projeto para o MT5 do Windows
# Usar no PowerShell (como Admin se necessário)

# Defina aqui o caminho da pasta MQL5 do seu MT5
$MT5_MQL5_PATH = "C:\Program Files\easyMarkets MetaTrader 5\MQL5"

# Caminhos origem (assumindo que este script está no diretório raiz do projeto)
$SOURCE_INCLUDE = ".\Include\FGM_TrendRider_EA"
$SOURCE_EXPERTS = ".\Experts\FGM_TrendRider_EA"
$SOURCE_INDICATORS = ".\Indicators\FGM_TrendRider_EA"

# Caminhos destino
$DEST_INCLUDE = "$MT5_MQL5_PATH\Include\FGM_TrendRider_EA"
$DEST_EXPERTS = "$MT5_MQL5_PATH\Experts\FGM_TrendRider_EA"
$DEST_INDICATORS = "$MT5_MQL5_PATH\Indicators\FGM_TrendRider_EA"

Write-Host "╔════════════════════════════════════════════════════╗"
Write-Host "║ Sincronizando arquivos para MT5 easyMarkets       ║"
Write-Host "╚════════════════════════════════════════════════════╝"
Write-Host ""

# Função para sincronizar diretório
function Sync-Directory {
    param (
        [string]$Source,
        [string]$Dest,
        [string]$Description
    )
    
    if (Test-Path $Source) {
        Write-Host "📂 Sincronizando $Description..."
        
        # Criar destino se não existir
        if (!(Test-Path $Dest)) {
            New-Item -Path $Dest -ItemType Directory -Force | Out-Null
            Write-Host "   ✓ Diretório criado: $Dest"
        }
        
        # Copiar arquivos
        $files = Get-ChildItem -Path $Source -File
        foreach ($file in $files) {
            $destFile = Join-Path -Path $Dest -ChildPath $file.Name
            Copy-Item -Path $file.FullName -Destination $destFile -Force
            Write-Host "   ✓ $($file.Name) copiado"
        }
    } else {
        Write-Host "   ⚠ Fonte não encontrada: $Source"
    }
    
    Write-Host ""
}

# Sincronizar cada diretório
Sync-Directory -Source $SOURCE_INCLUDE -Dest $DEST_INCLUDE -Description "Include files"
Sync-Directory -Source $SOURCE_EXPERTS -Dest $DEST_EXPERTS -Description "Expert Advisor"
Sync-Directory -Source $SOURCE_INDICATORS -Dest $DEST_INDICATORS -Description "Indicators"

Write-Host "╔════════════════════════════════════════════════════╗"
Write-Host "║ Sincronização concluída!                           ║"
Write-Host "║ Recompile o EA no MT5 para carregar as mudanças   ║"
Write-Host "╚════════════════════════════════════════════════════╝"
