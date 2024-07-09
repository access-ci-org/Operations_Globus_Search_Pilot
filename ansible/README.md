# Provisioning process

## Execute ONCE to bootstrap the new server
    # Set in hosts ansible_user, ansible_ssh_private_key_file appropriately for distro
    $ ansible-playbook -i hosts --vault-id ~/ansible_vault_password bootstrap_server_playbook.yml --limit=<HOST>

## Execut AS NEEDED to apply the latest configurations

Application support framework (directory and nginx server) supportting one or more dgpf or other applications.

- application_playbook.yml     Everything to setup the webserver and all applications

- dgpf1.yml                    Configures the first dgpf application

$ ansible-playbook -i hosts --vault-id ~/ansible_vault_password application_playbook.yml --limit=search-pilot.operations.access-ci.org

### Useful commands

$ ansible-vault encrypt_string --vault-id=~/ansible_vault_password '<password>' --name '<NAME>'
$ ansible-vault encrypt        --vault-id=~/ansible_vault_password <FILE>
$ ansible localhost            --vault-id=~/ansible_vault_password -m debug -a var='<VAR>' -e "@passwords.yml"

# In /etc/nginx/sites-enabled/nginx.serviceindex update per comments "server { listen 80 ..." entry
# systemctl restart nginx
# Fetch renew_cert.sh results
$ ansible-playbook -i hosts --vault-id ~/ansible_vault_password fetch_ssl_playbook.yml --limit=search-pilot.operations.access-ci.org
# Copy fetched file to files/letsencrypt/signed_chain.crt
# Undo nginx.serviceindex update, restart nginx

