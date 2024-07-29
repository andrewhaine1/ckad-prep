# ckad-prep
My CKAD Preparation Repo

Init with AzureRM backend args
```
terraform init -backend-config="resource_group_name=rg-andrew-haine" -backend-config="storage_account_name=iacconfigstore" -backend-config="container_name=terraform" -backend-config="key=terraform.tfstate"
```
