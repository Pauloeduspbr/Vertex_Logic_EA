#!/bin/bash

# Script para sincronizar arquivos do projeto para MT5 no Wine
# Use: ./sync_to_wine_mt5.sh

echo "╔════════════════════════════════════════════════════╗"
echo "║ Sincronizando arquivos para MT5 no Wine           ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

# Detectar o diretório do Wine/MT5
# Tente encontrar a instalação do MT5 no Wine
WINE_DRIVE_C="$HOME/.wine/drive_c"
EASYMARKETS_MT5="$WINE_DRIVE_C/Program Files/easyMarkets MetaTrader 5/MQL5"
REGULAR_MT5="$WINE_DRIVE_C/Program Files/MetaTrader 5/MQL5"

# Verificar qual existe
if [ -d "$EASYMARKETS_MT5" ]; then
    MT5_MQL5="$EASYMARKETS_MT5"
    echo "✓ Encontrado: easyMarkets MetaTrader 5"
elif [ -d "$REGULAR_MT5" ]; then
    MT5_MQL5="$REGULAR_MT5"
    echo "✓ Encontrado: MetaTrader 5"
else
    echo "⚠ ERRO: Não foi possível encontrar MT5 no Wine"
    echo ""
    echo "Caminhos procurados:"
    echo "  - $EASYMARKETS_MT5"
    echo "  - $REGULAR_MT5"
    echo ""
    echo "Se o MT5 está instalado em outro local, configure manualmente:"
    echo "  export MT5_MQL5='/caminho/para/MQL5'"
    echo "  $0"
    exit 1
fi

echo "Caminho MQL5: $MT5_MQL5"
echo ""

# Caminhos origem (Linux)
SOURCE_INCLUDE="./Include/FGM_TrendRider_EA"
SOURCE_EXPERTS="./Experts/FGM_TrendRider_EA"
SOURCE_INDICATORS="./Indicators/FGM_TrendRider_EA"

# Caminhos destino (Wine)
DEST_INCLUDE="$MT5_MQL5/Include/FGM_TrendRider_EA"
DEST_EXPERTS="$MT5_MQL5/Experts/FGM_TrendRider_EA"
DEST_INDICATORS="$MT5_MQL5/Indicators/FGM_TrendRider_EA"

# Função para sincronizar diretório
sync_directory() {
    local source=$1
    local dest=$2
    local description=$3
    
    if [ -d "$source" ]; then
        echo "📂 Sincronizando $description..."
        
        # Criar destino se não existir
        mkdir -p "$dest"
        
        # Copiar arquivos
        for file in "$source"/*; do
            if [ -f "$file" ]; then
                filename=$(basename "$file")
                cp "$file" "$dest/$filename"
                echo "   ✓ $filename copiado"
            fi
        done
        echo ""
    else
        echo "   ⚠ Fonte não encontrada: $source"
        echo ""
    fi
}

# Sincronizar cada diretório
sync_directory "$SOURCE_INCLUDE" "$DEST_INCLUDE" "Include files"
sync_directory "$SOURCE_EXPERTS" "$DEST_EXPERTS" "Expert Advisor"
sync_directory "$SOURCE_INDICATORS" "$DEST_INDICATORS" "Indicators"

echo "╔════════════════════════════════════════════════════╗"
echo "║ Sincronização concluída!                           ║"
echo "║ Recompile o EA no MT5 (F7 ou Ctrl+Shift+B)       ║"
echo "╚════════════════════════════════════════════════════╝"
