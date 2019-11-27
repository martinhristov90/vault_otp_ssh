#!/usr/bin/env bash

# Setting Vault Address, it is running on localhost at port 8200
export VAULT_ADDR=http://127.0.0.1:8200

# Setting the Vault Address in Vagrant user bash profile
grep "VAULT_ADDR" ~/.bash_profile  > /dev/null 2>&1 || {
echo "export VAULT_ADDR=http://127.0.0.1:8200" >> ~/.bash_profile
}

echo "Check if Vault is already initialized..."
if [ `vault status -address=${VAULT_ADDR}| awk 'NR==4 {print $2}'` == "true" ]
then
    echo "Vault already initialized...Exiting..."
    exit 1
fi

# Making working dir for Vault setup
mkdir -p /home/vagrant/_vaultSetup
touch /home/vagrant/_vaultSetup/keys.txt

echo "Setting up PKI admin user..."

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
vault write ssh-client/roles/otp_key_role key_type=otp \
        default_user=ubuntu \
        cidr_list=0.0.0.0/0

# Creating policy for user that has only access for generating OTP
vault policy write ssh-regular-user-policy /vagrant/configs/vault_roles/regular-user-role-policy.hcl

# Enabling userpass for ssh clients
echo "Enabling userpass for ssh clients"
vault auth enable -path=ssh_userpass userpass > /dev/null 2>&1

# Creating regular and root users in userpass dedicated to ssh clients
# INSECURE PASSWORD HERE !!! 
echo "Creating regular user in userpass dedicated to ssh clients"
vault write auth/ssh_userpass/users/regular \
  password="regular" \
  policies="ssh-regular-user-policy" > /dev/null 2>&1