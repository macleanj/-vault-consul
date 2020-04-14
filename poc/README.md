# Vault PoC
The following examples demonstrate various functionalities and applicabilities of Vault.
- Jenkins
- Kubernetes
- SSH
- Database

## Jenkins
See Jenkins repo for details

## Kubernetes
The following will setup getting secrets from Vault into the Kubernetes environment. An entire example is given [here](../vault-guides/identity/vault-agent-k8s-demo/README.md). In short:
```
# setup Vault
cd ../vault-guides/identity/vault-agent-k8s-demo
./setup-k8s-auth.sh

# Run pod
kubectl apply -f example-k8s-spec.yml --record

# Init container to show token. Init container is very quick!!
kubectl exec -it vault-agent-example --container vault-agent-auth echo $(cat /home/vault/.vault-token)

kubectl port-forward pod/vault-agent-example 8080:80
# Browser to http://localhost:8080 and see username  / password
# change password in Vault
```

## SSH
Prepare SSH container
```
docker-compose up

ssh -p 3000 root@localhost # vaultpwd
/root/vault-ssh-setup.sh
vault-ssh-helper -dev -verify-only -config=/etc/vault-ssh-helper.d/config.hcl
adduser vaultuser # vault (does not matter which password)

# Change below in /etc/pam.d/sshd and restart
#@include common-auth
auth requisite pam_exec.so quiet expose_authtok log=/tmp/vaultssh.log /usr/local/bin/vault-ssh-helper -dev -config=/etc/vault-ssh-helper.d/config.hcl
auth optional pam_unix.so not_set_pass use_first_pass nodelay
```

Setup vault
```
vault secrets enable ssh
vault write ssh/roles/admin key_type=otp default_user=vaultuser cidr_list=0.0.0.0/0,0.0.0.0/0

vault write ssh/creds/admin ip=172.16.238.20
# Copy key and login
ssh -p 3000 vaultuser@localhost # copy key as password

# When extra login
vault write ssh/creds/admin ip=172.16.238.20
# Copy key and login
ssh -p 3000 vaultuser@localhost # copy key as password
```

## Database
Prepare mariadb container
```
docker-compose up
```

Setup vault
```
vault secrets enable database
./mariadb/setup_commands.sh
vault policy write datareader mariadb/datareader.hcl
vault policy write datawriter mariadb/datawriter.hcl
vault token create -policy=datareader
vault token create -policy=datawriter

# At this point datareader can login and is able to generate a OTP username/password to login.
vault read database/creds/datareader
mysql -uv-root-datareader-VODC3XA6kXfkSQ -pA1a-VwlpnlkA4LOKK0D3 -h local.lab.crosslogic-consulting.com
# try to create table
create database testdbNOK;
# Access denied

vault read database/creds/datawriter
mysql -uv-root-datawriter-vMOiPVAUZifkq3 -pA1a-rPc1qW8eeOsLn48e -h local.lab.crosslogic-consulting.com
# try to create database
create database testdbOK;
# OK
```





# Background information
```
kubectl apply -f vault_sa.yaml
k8s_host="$(kubectl config view --minify | grep server | cut -f 2- -d ":" | tr -d " ")"
k8s_cacert="$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 --decode)"
secret_name="$(kubectl get serviceaccount -n default vault-auth -o go-template='{{ (index .secrets 0).name }}')"
account_token="$(kubectl get secret -n default ${secret_name} -o go-template='{{ .data.token }}' | base64 --decode)"

vault auth enable kubernetes
vault write auth/kubernetes/config \
  token_reviewer_jwt="${account_token}" \
  kubernetes_host="${k8s_host}" \
  kubernetes_ca_cert="${k8s_cacert}"

vault policy write vault-auth_policy vault-auth_policy.hcl
vault write auth/kubernetes/role/vault-auth bound_service_account_names=vault-auth bound_service_account_namespaces=default policies=vault-auth_policy ttl=1h
```

Test it
```
kubectl run -it --rm --serviceaccount=vault-auth --restart=Never test --image=ubuntu bash

# From within the container
apt-get update -y && apt-get install vim curl jq mysql-client -y

# Let's get the service account JWT token
JWT="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"

# Now we can use this to get the vault token. Using the vagrant IP address of Kubernetes.
VAULT_ADDRESS=10.0.2.2:8200
VAULT_TOKEN="$(curl --request POST --data '{"jwt": "'"$JWT"'", "role": "vault-auth"}' -s -k http://${VAULT_ADDRESS}/v1/auth/kubernetes/login | jq -r '.auth.client_token')"
```