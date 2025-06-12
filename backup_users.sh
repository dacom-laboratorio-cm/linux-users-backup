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

# Função para mostrar uso
show_usage() {
    echo "Uso: $0 [opções]"
    echo "Opções:"
    echo "  -f, --full     Backup completo (incluindo diretórios home)"
    echo "  -i, --info     Apenas informações de conta (sem diretórios home)"
    echo "  -h, --help     Mostrar esta mensagem de ajuda"
    exit 1
}

# Verificar argumentos
if [ $# -eq 0 ]; then
    show_usage
fi

BACKUP_TYPE=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--full)
            BACKUP_TYPE="full"
            shift
            ;;
        -i|--info)
            BACKUP_TYPE="info"
            shift
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            echo -e "${RED}Opção inválida: $1${NC}"
            show_usage
            ;;
    esac
done

# Criar diretório de backup com timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/root/user_backups/backup_${TIMESTAMP}"
mkdir -p "$BACKUP_DIR"

echo -e "${YELLOW}Iniciando backup de usuários...${NC}"

# Função para fazer backup das informações de conta
backup_user_info() {
    local username=$1
    local backup_file="${BACKUP_DIR}/${username}_info.txt"
    
    echo "=== Informações do usuário: $username ===" > "$backup_file"
    echo "Data do backup: $(date)" >> "$backup_file"
    echo "" >> "$backup_file"
    
    # Informações do /etc/passwd
    grep "^$username:" /etc/passwd >> "$backup_file"
    echo "" >> "$backup_file"
    
    # Informações do /etc/shadow (apenas hash da senha)
    grep "^$username:" /etc/shadow | cut -d: -f1,2 >> "$backup_file"
    echo "" >> "$backup_file"
    
    # Grupos do usuário
    echo "Grupos:" >> "$backup_file"
    groups "$username" >> "$backup_file"
    echo "" >> "$backup_file"
    
    # Informações adicionais
    echo "UID:" >> "$backup_file"
    id "$username" >> "$backup_file"
}

# Função para fazer backup do diretório home
backup_home_dir() {
    local username=$1
    local home_dir="/home/$username"
    
    if [ -d "$home_dir" ]; then
        echo -e "${YELLOW}Fazendo backup do diretório home de $username...${NC}"
        tar -czf "${BACKUP_DIR}/${username}_home.tar.gz" -C /home "$username"
    fi
}

# Listar todos os usuários que têm diretório em /home
echo -e "${YELLOW}Procurando usuários em /home...${NC}"
for user_home in /home/*; do
    if [ -d "$user_home" ]; then
        username=$(basename "$user_home")
        echo -e "${GREEN}Processando usuário: $username${NC}"
        
        # Sempre fazer backup das informações
        backup_user_info "$username"
        
        # Se for backup completo, incluir diretório home
        if [ "$BACKUP_TYPE" = "full" ]; then
            backup_home_dir "$username"
        fi
    fi
done

# Criar arquivo de resumo
echo "=== Resumo do Backup ===" > "${BACKUP_DIR}/resumo.txt"
echo "Data: $(date)" >> "${BACKUP_DIR}/resumo.txt"
echo "Tipo de backup: $BACKUP_TYPE" >> "${BACKUP_DIR}/resumo.txt"
echo "Usuários processados:" >> "${BACKUP_DIR}/resumo.txt"
ls -1 "${BACKUP_DIR}" | grep "_info.txt" | sed 's/_info.txt//' >> "${BACKUP_DIR}/resumo.txt"

echo -e "${GREEN}Backup concluído com sucesso!${NC}"
echo -e "${GREEN}Diretório de backup: $BACKUP_DIR${NC}"
echo -e "${YELLOW}Verifique o arquivo resumo.txt para mais detalhes${NC}" 