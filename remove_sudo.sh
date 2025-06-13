#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Este script precisa ser executado como root (sudo)${NC}"
    exit 1
fi

# Lista de usuários para remover do sudo
# Adicione ou remova usuários conforme necessário
USERS=(
    "aGabrielaSereniski"
    "aGuilhermeLopes"
    "aHiagoVieira"
    "aJoaoBriganti"
    "aJulioNogueira"
    "aluno"
    "aPauloSilva"
    "aWilliamRodrigues"
    "joaof"
    "rag"
)

echo -e "${YELLOW}Removendo usuários do grupo sudo...${NC}"

for user in "${USERS[@]}"; do
    if id "$user" &>/dev/null; then
        if groups "$user" | grep -q sudo; then
            gpasswd -d "$user" sudo
            echo -e "${GREEN}Usuário $user removido do grupo sudo${NC}"
        else
            echo -e "${YELLOW}Usuário $user não está no grupo sudo${NC}"
        fi
    else
        echo -e "${RED}Usuário $user não existe${NC}"
    fi
done

echo -e "${GREEN}Processo concluído!${NC}" 