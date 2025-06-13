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
    echo "Uso: $0 [opções] <diretório_de_backup>"
    echo "Opções:"
    echo "  -f, --full     Restauração completa (incluindo diretórios home)"
    echo "  -i, --info     Apenas restauração de contas (sem diretórios home)"
    echo "  -h, --help     Mostrar esta mensagem de ajuda"
    echo ""
    echo "Exemplo: $0 -f /root/user_backups/backup_20240315_123456"
    exit 1
}

# Verificar argumentos
if [ $# -lt 2 ]; then
    show_usage
fi

BACKUP_TYPE=""
BACKUP_DIR=""

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
            if [ -z "$BACKUP_DIR" ]; then
                BACKUP_DIR="$1"
            else
                echo -e "${RED}Argumento inválido: $1${NC}"
                show_usage
            fi
            shift
            ;;
    esac
done

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

echo -e "${YELLOW}Iniciando restauração de usuários...${NC}"

# Função para criar usuário com as informações do backup
restore_user_account() {
    local username=$1
    local info_file="${BACKUP_DIR}/${username}_info.txt"
    
    if [ ! -f "$info_file" ]; then
        echo -e "${RED}Arquivo de informações não encontrado para o usuário: $username${NC}"
        return 1
    fi
    
    # Extrair informações do arquivo de backup
    local passwd_line=$(grep "^$username:" "$info_file" | head -n 1)
    local shadow_line=$(grep "^$username:" "$info_file" | grep -v "^$username:.*:.*:.*:.*:.*:.*:.*:.*:.*$" | head -n 1)
    
    if [ -z "$passwd_line" ]; then
        echo -e "${RED}Informações do usuário não encontradas no backup: $username${NC}"
        return 1
    fi
    
    # Extrair UID e GID
    local uid=$(echo "$passwd_line" | cut -d: -f3)
    local gid=$(echo "$passwd_line" | cut -d: -f4)
    local home_dir=$(echo "$passwd_line" | cut -d: -f6)
    local shell=$(echo "$passwd_line" | cut -d: -f7)
    
    # Verificar se o usuário já existe
    if id "$username" &>/dev/null; then
        echo -e "${YELLOW}Usuário $username já existe. Pulando...${NC}"
        return 0
    fi
    
    # Criar grupo se não existir
    if ! getent group "$gid" &>/dev/null; then
        groupadd -g "$gid" "$username"
    fi
    
    # Criar usuário
    useradd -u "$uid" -g "$gid" -d "$home_dir" -s "$shell" "$username"
    
    # Restaurar senha se disponível
    if [ ! -z "$shadow_line" ]; then
        local password_hash=$(echo "$shadow_line" | cut -d: -f2)
        if [ ! -z "$password_hash" ]; then
            echo "$username:$password_hash" | chpasswd -e
        fi
    fi
    
    # Restaurar grupos adicionais
    local groups=$(grep "Grupos:" -A 1 "$info_file" | tail -n 1)
    if [ ! -z "$groups" ]; then
        for group in $groups; do
            # Ignorar o grupo principal do usuário e caracteres especiais
            if [ "$group" != "$username" ] && [ "$group" != ":" ] && [ "$group" != "," ]; then
                # Verificar se o grupo existe antes de adicionar
                if getent group "$group" &>/dev/null; then
                    usermod -a -G "$group" "$username"
                else
                    echo -e "${YELLOW}Aviso: Grupo '$group' não existe no sistema${NC}"
                fi
            fi
        done
    fi
    
    echo -e "${GREEN}Usuário $username restaurado com sucesso${NC}"
    return 0
}

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

# Criar grupos necessários antes de começar
create_required_groups

# Função para restaurar diretório home
restore_home_dir() {
    local username=$1
    local home_archive="${BACKUP_DIR}/${username}_home.tar.gz"
    
    if [ ! -f "$home_archive" ]; then
        echo -e "${YELLOW}Arquivo de backup do diretório home não encontrado para: $username${NC}"
        return 1
    fi
    
    # Verificar se o usuário existe
    if ! id "$username" &>/dev/null; then
        echo -e "${RED}Usuário $username não existe. Não é possível restaurar o diretório home.${NC}"
        return 1
    fi
    
    # Restaurar diretório home
    echo -e "${YELLOW}Restaurando diretório home para $username...${NC}"
    tar -xzf "$home_archive" -C /home
    
    # Ajustar permissões
    chown -R "$username:$username" "/home/$username"
    chmod 700 "/home/$username"
    
    echo -e "${GREEN}Diretório home restaurado para $username${NC}"
    return 0
}

# Ler lista de usuários do arquivo de resumo
echo -e "${YELLOW}Lendo lista de usuários do backup...${NC}"
USERS=$(grep -A 1000 "Usuários processados:" "${BACKUP_DIR}/resumo.txt" | tail -n +2)

# Processar cada usuário
for username in $USERS; do
    echo -e "${YELLOW}Processando usuário: $username${NC}"
    
    # Restaurar conta
    if restore_user_account "$username"; then
        # Se for restauração completa, restaurar diretório home
        if [ "$BACKUP_TYPE" = "full" ]; then
            restore_home_dir "$username"
        fi
    fi
done

echo -e "${GREEN}Restauração concluída!${NC}"
echo -e "${YELLOW}Verifique se todos os usuários foram restaurados corretamente${NC}"
echo -e "${YELLOW}Recomendado: Verificar as permissões dos diretórios home e testar o login dos usuários${NC}" 