# ansiblHobo

Projet Ansible pour la gestion et le déploiement de mon homeserver Linux (et à terme Windows).

## Structure

```
ansiblHobo/
├── inventory/
│   └── inventory.ini         # Hôtes cibles
├── group_vars/
│   └── all.yml               # Variables globales
├── files/
│   ├── nginx/                # Configs nginx (nginx.conf, sites-available, snippets)
│   └── vault/                # Fichiers sensibles chiffrés (ansible-vault)
├── playbooks/
│   ├── base.yml              # Bootstrap complet (user + config de base)
│   ├── user.yml              # Création des users, clés SSH
│   ├── cron.yml              # Déploiement des crons
│   ├── nginx.yml             # Installation et configuration nginx + certbot
│   ├── docker/
│   │   └── docker.yml        # Clone cloudHobo + déploiement des configs Docker
│   └── security/
│       ├── security.yml      # Playbook de sécurité global
│       ├── ssh.yml           # Hardening SSH
│       ├── ufw.yml           # Pare-feu UFW
│       └── fail2ban.yml      # Fail2ban
└── scripts/
    ├── package_vault.sh      # Collecte et chiffre les configs sensibles de cloudHobo
    └── copyNginx.sh          # Copie les configs nginx vers files/nginx/
```

## Prérequis

- Ansible installé sur la machine de contrôle
- Accès SSH avec clé au serveur cible
- `ansible-vault` configuré avec `.vault_pass` (gitignored)

## Vault

Les fichiers sensibles sont chiffrés avec `ansible-vault` et stockés dans `files/vault/` :

| Fichier | Contenu |
|---|---|
| `sensitive_configs.tar.gz.vault` | Configs Docker (volumes, secrets, tokens…) |
| `git_keys.vault` | Clé SSH privée GitHub |
| `ovh.ini` | Credentials API OVH (certbot DNS challenge) |
| `svenlabs.fr.conf` | Config de renouvellement Let's Encrypt |

Le mot de passe vault est stocké dans `.vault_pass` à la racine du repo (gitignored).

## Utilisation

```bash
# Configuration de base du serveur
ansible-playbook -i inventory/inventory.ini playbooks/base.yml --vault-password-file .vault_pass

# Nginx + SSL
ansible-playbook -i inventory/inventory.ini playbooks/nginx.yml --vault-password-file .vault_pass

# Déploiement des configs Docker
ansible-playbook -i inventory/inventory.ini playbooks/docker/docker.yml --vault-password-file .vault_pass

# Crons
ansible-playbook -i inventory/inventory.ini playbooks/cron.yml --vault-password-file .vault_pass

# Sécurité
ansible-playbook -i inventory/inventory.ini playbooks/security/security.yml --vault-password-file .vault_pass
```

## Scripts

### `package_vault.sh`
Collecte les fichiers sensibles de `cloudHobo` (configs, secrets, `.storage` Home Assistant),
les archive et les chiffre avec `ansible-vault`. Lancé automatiquement par cron à 3h.

```bash
./scripts/package_vault.sh
```

### `copyNginx.sh`
Copie les configs nginx (`nginx.conf`, `sites-available/`, `snippets/`) vers `files/nginx/`.
Lancé automatiquement par cron à 3h.

```bash
./scripts/copyNginx.sh
```

## Crons déployés

| Fréquence | User | Commande |
|---|---|---|
| Toutes les 10 min | sven | Healthcheck ping (healthchecks.io) |
| Tous les jours à 3h | sven | `package_vault.sh` |
| Tous les jours à 3h | sven | `copyNginx.sh` |
| Toutes les 12h | root | `certbot renew` |

Les logs sont centralisés dans `/var/log/ansiblHobo.log`.

## Roadmap

- [ ] Déploiement définitif des containers Docker (`docker compose up`)
- [ ] Gestion Windows
- [ ] Refacto en roles Ansible
