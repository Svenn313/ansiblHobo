# ansiblHobo

Projet Ansible pour la gestion et le déploiement de mon homeserver Linux (et à terme Windows).

## Structure

```
ansiblHobo/
├── ansible.cfg
├── site.yml                      # Playbook principal (appelle les rôles, avec tags)
├── requirements.yml              # Rôle geerlingguy.docker + collections
├── inventory/
│   ├── inventory.ini
│   └── group_vars/
│       └── all/
│           ├── all.yml           # Variables globales
│           └── vault.yml         # Variables sensibles chiffrées
├── windows.yml                   # Playbook Windows (séparé de site.yml)
├── roles/
│   ├── users/                    # Users, clés SSH, ssh config
│   ├── base/                     # Paquets, zsh/oh-my-zsh, git, timezone, locale, XDG
│   ├── unattended_upgrades/      # MAJ de sécurité auto + reboot planifié (05:30)
│   ├── security/                 # ssh (+ durcissement), ufw, fail2ban
│   ├── docker/                   # geerlingguy.docker + rotation des logs
│   ├── docker_maintenance/       # Cron docker prune hebdo
│   ├── cloudhobo/                # Clone cloudHobo, secrets vault, docker compose up
│   ├── nginx/                    # nginx + certbot
│   ├── notify/                   # notify-matrix, alertes disque/SMART
│   ├── backup/                   # restic : backup.sh, restic-verify (check + test de restauration)
│   ├── cron/                     # certbot, healthcheck
│   └── windows/                  # Chocolatey, timezone
```

Chaque rôle suit la structure standard : `tasks/`, `defaults/`, `handlers/`, `files/`, `templates/`, `meta/`.

## Utilisation

```bash
ansible-galaxy install -r requirements.yml
ansible-playbook site.yml                    # tout
ansible-playbook site.yml --tags nginx       # un seul rôle
ansible-playbook site.yml --tags ufw         # une sous-partie de security
```

## Réinstallation après formatage

Ansible reconstruit la **config de l'hôte** ; les **containers** (volumes, secrets) sont restaurés depuis restic (backup quotidien chez un ami).

### Sur le serveur lui-même (procédure de restauration)

1. Installer Ubuntu Server 24.04 avec l'utilisateur `sven`.
2. `sudo apt install ansible git`, puis récupérer ce dépôt : `git clone https://github.com/svenn313/ansiblHobo.git ~/git/ansiblHobo` (dépôt privé : jeton GitHub ou clé de déploiement temporaire).
3. `cd ~/git/ansiblHobo && ansible-galaxy install -r requirements.yml && ansible-galaxy collection install -r requirements.yml`
4. Lancer (demande le mot de passe du vault, puis le mot de passe sudo de `sven`) :

```bash
ansible-playbook site.yml --limit nuc
```

### Depuis une autre machine

Installer Ubuntu Server 24.04 avec `sven` et OpenSSH Server, puis `sudo apt install ansible sshpass` et les `ansible-galaxy` ci-dessus, et lancer `ansible-playbook site.yml --limit nuc -e ansible_connection=ssh -e ansible_host=<IP> -e ansible_port=22923`.

Tout est automatique :

- **Port SSH** : celui de l'inventaire s'il répond, sinon le 22 d'une installation vierge (UFW garde alors le 22 ouvert pour la durée du run).
- **Connexion** : si la clé SSH n'est pas acceptée (serveur réinstallé), l'ancienne empreinte est oubliée et le mot de passe de `sven` est demandé (SSH + sudo, ce run seulement).
- **Containers** : si `~/git/cloudHobo` n'existe pas, le repo est cloné, restauré depuis restic puis démarré. Sur un serveur existant, rien n'est touché.
- **SSH** : le changement de port est appliqué en toute fin de run.

Options : `-e cloudhobo_force_restore=true` (restauration restic même si cloudHobo existe), `-e cloudhobo_compose_up=true` (`docker compose up` sur un serveur en place).

Le rôle `backup` redéploie la clé SSH (`resticBackup`) et le mot de passe du dépôt restic, chiffrés dans `roles/backup/files/vault/`.

## Prérequis

- Ansible installé sur la machine de contrôle
- Accès SSH avec clé au serveur cible
- Mot de passe `ansible-vault` (demandé à chaque lancement, rien n'est stocké sur le disque)

## Vault

Les fichiers sensibles sont chiffrés avec `ansible-vault` et stockés dans `files/vault/` de chaque rôle :

| Fichier | Rôle | Contenu |
|---|---|---|
| `resticBackup.vault`, `restic-password.vault` | backup | Accès au dépôt restic distant |
| `git_keys.vault` (+ autres clés) | users | Clé SSH privée GitHub |
| `ovh.ini` | nginx | Credentials API OVH (certbot DNS challenge) |
| `svenlabs.fr.conf` | nginx | Config de renouvellement Let's Encrypt |

Le mot de passe vault n'est stocké nulle part : Ansible le demande à chaque exécution.

## Crons déployés

| Fréquence | User | Commande |
|---|---|---|
| Toutes les 10 min | sven | Healthcheck ping (healthchecks.io) |
| Toutes les 12h | root | `certbot renew` |

Les logs sont centralisés dans `/var/log/ansiblHobo.log`.

## Roadmap

- [x] Déploiement des containers Docker (rôle `cloudhobo`)
- [~] Gestion Windows (rôle de base, à compléter)
- [x] Refacto en roles Ansible

## Sécurité des secrets

- Tout ce qui est sensible est chiffré avec `ansible-vault` (`*.vault`, `vault.yml`, `ovh.ini`, `svenlabs.fr.conf`) ; le mot de passe vault n'est stocké nulle part.
- Les secrets déployés ont des permissions strictes (`0600`, `.ssh` en `0700`) et leur contenu n'apparaît pas dans `--diff`.
- Variables du vault : `ssh_port`, `restic_repo`, `vault_matrix_notify_token`, `vault_matrix_notify_room`, `vault_healthcheck_url`.
- `.gitignore` bloque les clés et mots de passe non chiffrés (`*Key`, `id_*`, `*.key`, `*.pem`, `.env`…).

## Modifier la config nginx

La config nginx est dans `roles/nginx/files/nginx/` et déployée par Ansible : modifier le repo puis `ansible-playbook site.yml --tags nginx`. Pour désactiver un site sans le supprimer, l'ajouter à `nginx_sites_disabled` (`roles/nginx/defaults/main.yml`).
