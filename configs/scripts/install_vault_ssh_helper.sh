# installing needed utilities
# VARS
SSHD_CONFIG_PATH="/etc/ssh/sshd_config"
PAM_SSHD="/etc/pam.d/sshd"

sudo apt-get update
sudo apt-get install -y curl unzip

# Download vault helper with curl
curl -sC - -k https://releases.hashicorp.com/vault-ssh-helper/0.1.4/vault-ssh-helper_0.1.4_linux_amd64.zip -o vault-ssh-helper.zip
# Unzip in the current dir
unzip vault-ssh-helper.zip
# Move it to the PATH
sudo mv vault-ssh-helper /usr/local/bin/

# Creating config dir for vault ssh helper
sudo mkdir /etc/vault-ssh-helper.d

# Neat trick to use heredoc with sudo
sudo tee /etc/vault-ssh-helper.d/config.hcl > /dev/null << EOL
vault_addr = "http://192.168.1.10:8200"
ssh_mount_point = "ssh-client"
#CAUTION tls disabled
#ca_cert = "/etc/vault-ssh-helper.d/vault.crt"
tls_skip_verify = true
allowed_roles = "*"
EOL

sudo touch /var/log/vaultssh.log

# Neat trick to use heredoc with sudoec
sudo sed -i -e 's/@include common-auth/#@include common-auth/g' ${PAM_SSHD}
sudo echo "auth requisite pam_exec.so quiet expose_authtok log=/tmp/vaultssh.log /usr/local/bin/vault-ssh-helper -dev -config=/etc/vault-ssh-helper.d/config.hcl" >> ${PAM_SSHD}
sudo echo "auth optional pam_unix.so not_set_pass use_first_pass nodelay" >> ${PAM_SSHD}
#
# enable ChallengeResponseAuthentication
sudo sed -i -e 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' ${SSHD_CONFIG_PATH}
# allow to use PAM
sudo sed -i -e 's/UsePAM no/UsePAM yes/g' ${SSHD_CONFIG_PATH}
# disable password authentication
sudo sed -i -e 's/PasswordAuthentication yes/PasswordAuthentication no/g' ${SSHD_CONFIG_PATH}
# restart SSH server
sudo systemctl restart sshd