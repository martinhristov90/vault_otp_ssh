## HashiCorp Vault SSH using OTP

### Purpose :

- This repository purpose is to utilize the SSH backend of Hashicorp Vault

### What does it do ?

- It utilize the SSH vault secret backend to login to machine named "ubuntu_ssh" using OTP.

### How to use it ?

- `git clone https://github.com/martinhristov90/NAME_HETRE.git`
- Execute `vagrant up`
- You now have two VMs running "vault_server" (192.168.1.10) and "ubuntu_ssh" (192.168.1.20).
- Review provision scripts in `./configs/scripts` folder
- (Use either Curl or Postman) Execute following API call to get user token :
(If you are using TLS, need to import the ca-chain.cert.pem in Postman by going to Settings -> Certificate tab, and selecting it, otherwise, you get an error and API call can not be completed)
```
curl \
    --request POST \
    --data @payload.json \
    http://localhost:8200/v1/auth/ssh_userpass/login/regular
```

How `payload.json` should look like :
    ```
    {
    "password": "regular"
    }
    ```

Get the user token and execute the following API call to get OTP :

```
 curl --header "TOKEN_FROM_PREVIOUS_API_CALL" \ 
       --request POST \
       --data '{"ip": "192.168.1.20"}'
       https://127.0.0.1:8200/v1/ssh/creds/otp_key_role
```
Note: If you are using Postman, grab the user token from the previous API call and place it in Authentication tab, from drop-down menu select `Bearer Token`.

You should get similar response back :

```
{
    "request_id": "22e05e06-f8bd-7410-60e0-18d1b43a9182",
    "lease_id": "ssh-client/creds/otp_key_role/VBvIP2lLENBmJyq9AHZECQle",
    "renewable": false,
    "lease_duration": 2764800,
    "data": {
        "ip": "192.168.1.20",
        "key": "d6dd1482-f5e4-9b6f-4d9b-7e76294553e1",
        "key_type": "otp",
        "port": 22,
        "username": "ubuntu"
    },
    "wrap_info": null,
    "warnings": null,
    "auth": null
}
```

## CA and TLS

If you opt-in for using TLS in Vault you should know the following :

- The certificates inside the `./keys_COMPROMISED` (private keys have no password) folder should be considered COMPROMISED. You should generate your own, my recommendation is to use one Root CA and one Intermediate CA to sign the end certificates, there is a great article how to do that with OpenSSL [here](https://jamielinux.com/docs/openssl-certificate-authority/introduction.html). Also, when generating certificates keep in mind that SANs should be included while signing it. About SANs [here](http://apetec.com/support/generatesan-csr.htm)

- To enable TLS on the Vault server your `/etc/vauld.d/vault.hcl` should look like this :

```
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
```

- On the `ubuntu_ssh` machine your Vault SSH help config file (`/etc/vault-ssh-helper.d/config.hcl`)
    - Create file named /etc/vault-ssh-helper.d/vault.crt and place the contents of `ca-chain.cert.pem` in it.

```
vault_addr = "https://192.168.1.10:8200"
ssh_mount_point = "ssh-client"
ca_cert = "/etc/vault-ssh-helper.d/vault.crt"
tls_skip_verify = false
allowed_roles = "*"
```

- If you put password on the private key used by Vault, for example using (openssl rsa -aes256 -in [file1.key] -out [file2.key]), this password should be entered every time the Vault server is started.

- Vault is also capable of acting as CA. More info [here](https://github.com/martinhristov90/vault_ca)

### Security Notes !
- Shares of the secret key for unsealing Vault and root token are saved to file /home/vagrant/_vaultSetup/keys.txt to be used for deployment process, take care of them.
- Keep in mind that vagrant user is logged in with root token during the deployment process, to log-out execute `rm ~/.vault-token`