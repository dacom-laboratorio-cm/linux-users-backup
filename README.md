# Scripts de Backup e Restauração de Usuários Linux

Este conjunto de scripts permite fazer backup e restauração de usuários em sistemas Linux baseados em Debian. Os scripts são úteis para migração de sistemas, backup de contas de usuários e restauração em novos servidores.

## Requisitos

- Sistema operacional Linux baseado em Debian (Ubuntu, Debian, etc.)
- Privilégios de root (sudo)
- Bash shell
- Utilitários básicos do sistema (tar, grep, etc.)

## Scripts Disponíveis

### 1. backup_users.sh

Script para fazer backup das contas de usuários e seus diretórios home.

#### Uso:
```bash
sudo ./backup_users.sh [opções]
```

#### Opções:
- `-f, --full`: Backup completo (incluindo diretórios home)
- `-i, --info`: Apenas informações de conta (sem diretórios home)
- `-h, --help`: Mostrar mensagem de ajuda

#### Exemplos:
```bash
# Backup completo (contas + diretórios home)
sudo ./backup_users.sh -f

# Backup apenas das informações de conta
sudo ./backup_users.sh -i
```

#### O que é feito no backup:
- Informações do /etc/passwd
- Hash das senhas do /etc/shadow
- Grupos dos usuários
- UIDs e GIDs
- Diretórios home (opcional)
- Arquivo de resumo com detalhes do backup

### 2. restore_users.sh

Script para restaurar as contas de usuários e seus diretórios home em um novo sistema.

#### Uso:
```bash
sudo ./restore_users.sh [opções] <diretório_de_backup>
```

#### Opções:
- `-f, --full`: Restauração completa (incluindo diretórios home)
- `-i, --info`: Apenas restauração de contas (sem diretórios home)
- `-h, --help`: Mostrar mensagem de ajuda

#### Exemplos:
```bash
# Restauração completa
sudo ./restore_users.sh -f /root/user_backups/backup_20240315_123456

# Restauração apenas das contas
sudo ./restore_users.sh -i /root/user_backups/backup_20240315_123456
```

#### O que é restaurado:
- Contas de usuários com UIDs e GIDs originais
- Hash das senhas
- Grupos e associações
- Diretórios home (opcional)
- Permissões dos diretórios

## Estrutura dos Backups

Os backups são armazenados em `/root/user_backups/` com a seguinte estrutura:

```
/root/user_backups/
└── backup_YYYYMMDD_HHMMSS/
    ├── resumo.txt
    ├── usuario1_info.txt
    ├── usuario1_home.tar.gz (se backup completo)
    ├── usuario2_info.txt
    ├── usuario2_home.tar.gz (se backup completo)
    └── ...
```

## Considerações de Segurança

1. **Permissões**:
   - Os scripts devem ser executados como root
   - Os backups são armazenados em `/root/user_backups/`
   - Diretórios home são restaurados com permissão 700

2. **Senhas**:
   - Apenas os hashes das senhas são armazenados
   - As senhas originais não são expostas

3. **Backup**:
   - Recomendado fazer backup do sistema antes de restaurar
   - Verificar conflitos de UID/GID antes da restauração

## Procedimento Recomendado para Migração

1. **No sistema original**:
   ```bash
   # Fazer backup completo
   sudo ./backup_users.sh -f
   ```

2. **Transferir o backup**:
   - Copie o diretório de backup para o novo sistema
   - Mantenha a estrutura de diretórios intacta

3. **No novo sistema**:
   ```bash
   # Verificar se há conflitos de UID/GID
   # Restaurar as contas
   sudo ./restore_users.sh -f /root/user_backups/backup_YYYYMMDD_HHMMSS
   ```

4. **Pós-restauração**:
   - Verificar login de todos os usuários
   - Confirmar permissões dos diretórios home
   - Testar acesso aos grupos
   - Verificar serviços dependentes

## Solução de Problemas

1. **Erro de permissão**:
   - Verifique se está executando como root
   - Confirme as permissões dos scripts (devem ser executáveis)

2. **Usuário já existe**:
   - O script pulará usuários existentes
   - Considere remover usuários conflitantes antes da restauração

3. **Erro na restauração do diretório home**:
   - Verifique espaço em disco
   - Confirme permissões do diretório /home
   - Verifique se o backup foi completo

## Contribuição

Sinta-se à vontade para reportar problemas ou sugerir melhorias através de issues e pull requests.

## Licença

Este projeto está sob a licença MIT. Veja o arquivo LICENSE para mais detalhes. 