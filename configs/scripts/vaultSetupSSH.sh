#!/usr/bin/env bash

# Setting Vault Address, it is running on localhost at port 8200
export VAULT_ADDR=https://127.0.0.1:8200
# Vault client should trust the CA
export VAULT_CACERT=/vagrant/keys_COMPROMISED/ca-chain.cert.pem

# Setting the Vault Address in Vagrant user bash profile
grep "VAULT_ADDR" ~/.bash_profile  > /dev/null 2>&1 || {
echo "export VAULT_ADDR=https://127.0.0.1:8200" >> ~/.bash_profile
}

# Setting up trusted CA
grep "VAULT_CACERT" ~/.bash_profile  > /dev/null 2>&1 || {
echo "export VAULT_CACERT=/vagrant/keys_COMPROMISED/ca-chain.cert.pem" >> ~/.bash_profile
}

# Stopping Vault
echo "Stopping Vault..."
sudo systemctl stop vault

# Overriding the Vault config file of the default box
sudo tee /etc/vault.d/vault.hcl > /dev/null << EOL
backend "file" {
path = "/vaultDataDir"
}
listener "tcp" {
address = "0.0.0.0:8200"
tls_disable = 0
tls_cert_file = "/vagrant/keys_COMPROMISED/vault_server.crt.pem"
tls_key_file = "/vagrant/keys_COMPROMISED/private/vault_server.key.pem"
}

# Enable UI
ui = true
EOL

# Starting Vault
echo "Starting Vault..."
sudo systemctl start vault

# Wait for Vault to start
echo "Waiting for Vault to start"
sleep 1

echo "Check if Vault is already initialized..."
if [ `vault status | awk 'NR==4 {print $2}'` == "true" ]
then
    echo "Vault already initialized...Exiting..."
    exit 1
fi

# Making working dir for Vault setup
mkdir -p /home/vagrant/_vaultSetup
touch /home/vagrant/_vaultSetup/keys.txt

echo "Initializing Vault..."
vault operator init -address=${VAULT_ADDR} > /home/vagrant/_vaultSetup/keys.txt
export VAULT_TOKEN=$(grep 'Initial Root Token:' /home/vagrant/_vaultSetup/keys.txt | awk '{print substr($NF, 1, length($NF))}')

echo "Unsealing vault..."
vault operator unseal -address=${VAULT_ADDR} $(grep 'Key 1:' /home/vagrant/_vaultSetup/keys.txt | awk '{print $NF}') > /dev/null 2>&1
vault operator unseal -address=${VAULT_ADDR} $(grep 'Key 2:' /home/vagrant/_vaultSetup/keys.txt | awk '{print $NF}') > /dev/null 2>&1
vault operator unseal -address=${VAULT_ADDR} $(grep 'Key 3:' /home/vagrant/_vaultSetup/keys.txt | awk '{print $NF}') > /dev/null 2>&1

echo "Auth with root token..."
vault login -address=${VAULT_ADDR} token=${VAULT_TOKEN} > /dev/null 2>&1

# Enabling userpass auth method.
echo "Enabling userpass auth method."
vault auth enable -address=${VAULT_ADDR} userpass > /dev/null 2>&1

# Enabling logging to a file
echo "Enabling logging to a file"
sudo touch /var/log/auditVault.log
sudo chown vault:vault /var/log/auditVault.log
vault audit enable file file_path=/var/log/auditVault.log

# Enable ssh secret backend at ssh-client/ path
echo "Enable ssh secret backend at ssh-client/ path"
vault secrets enable -path=ssh-client ssh

# Define a role 
# The role defines only one IP.
vault write ssh-client/roles/otp_key_role @/vagrant/configs/ssh_roles/otp_role.hcl

# Creating policy for user that has only access for generating OTP
vault policy write ssh-regular-user-policy /vagrant/configs/vault_roles/regular-user-role-policy.hcl

# Enabling userpass for ssh clients
echo "Enabling userpass for ssh clients"
vault auth enable -path=ssh_userpass -description="userpass backend for ssh OTP users" userpass > /dev/null 2>&1

# Creating regular and root users in userpass dedicated to ssh clients
# INSECURE PASSWORD HERE !!! 
echo "Creating regular user in userpass dedicated to ssh clients"
vault write auth/ssh_userpass/users/regular \
  password="regular" \
  policies="ssh-regular-user-policy" > /dev/null 2>&1