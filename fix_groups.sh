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

# Verificar argumentos
if [ $# -ne 1 ]; then
    echo "Uso: $0 <diretório_de_backup>"
    echo "Exemplo: $0 /root/user_backups/backup_20250612_143737"
    exit 1
fi

BACKUP_DIR="$1"

# Verificar se o diretório de backup existe
if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}Diretório de backup não encontrado: $BACKUP_DIR${NC}"
    exit 1
fi

# Verificar se existe o arquivo de resumo
if [ ! -f "${BACKUP_DIR}/resumo.txt" ]; then
    echo -e "${RED}Arquivo de resumo não encontrado. Diretório de backup inválido.${NC}"
    exit 1
fi

# Função para criar grupos necessários
create_required_groups() {
    local groups=("docker" "tecadm" "sudo" "adm" "dialout" "cdrom" "floppy" "audio" "dip" "video" "plugdev" "netdev" "lpadmin" "scanner" "sambashare")
    
    for group in "${groups[@]}"; do
        if ! getent group "$group" &>/dev/null; then
            echo -e "${YELLOW}Criando grupo: $group${NC}"
            groupadd "$group"
        fi
    done
}

# Função para corrigir grupos de um usuário
fix_user_groups() {
    local username=$1
    local info_file="${BACKUP_DIR}/${username}_info.txt"
    
    if [ ! -f "$info_file" ]; then
        echo -e "${RED}Arquivo de informações não encontrado para o usuário: $username${NC}"
        return 1
    fi
    
    # Verificar se o usuário existe
    if ! id "$username" &>/dev/null; then
        echo -e "${RED}Usuário $username não existe no sistema${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Corrigindo grupos para o usuário: $username${NC}"
    
    # Restaurar grupos adicionais
    local groups=$(grep "Grupos:" -A 1 "$info_file" | tail -n 1)
    if [ ! -z "$groups" ]; then
        for group in $groups; do
            # Ignorar o grupo principal do usuário e caracteres especiais
            if [ "$group" != "$username" ] && [ "$group" != ":" ] && [ "$group" != "," ]; then
                # Verificar se o grupo existe antes de adicionar
                if getent group "$group" &>/dev/null; then
                    usermod -a -G "$group" "$username"
                    echo -e "${GREEN}Adicionado ao grupo: $group${NC}"
                else
                    echo -e "${YELLOW}Aviso: Grupo '$group' não existe no sistema${NC}"
                fi
            fi
        done
    fi
    
    echo -e "${GREEN}Grupos corrigidos para o usuário $username${NC}"
    return 0
}

# Criar grupos necessários
echo -e "${YELLOW}Criando grupos necessários...${NC}"
create_required_groups

# Ler lista de usuários do arquivo de resumo
echo -e "${YELLOW}Lendo lista de usuários do backup...${NC}"
USERS=$(grep -A 1000 "Usuários processados:" "${BACKUP_DIR}/resumo.txt" | tail -n +2)

# Processar cada usuário
for username in $USERS; do
    fix_user_groups "$username"
done

echo -e "${GREEN}Correção de grupos concluída!${NC}"
echo -e "${YELLOW}Verifique se todos os usuários foram adicionados aos grupos corretamente${NC}" 