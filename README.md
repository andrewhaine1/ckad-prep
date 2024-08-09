# ckad-prep
My CKAD Preparation Repo

Init with AzureRM backend args (Not yet working)
```
terraform init \
-backend-config="resource_group_name=rg-andrew-haine" \
-backend-config="storage_account_name=iacconfigstore" \
-backend-config="container_name=terraform" \
-backend-config="key=terraform.tfstate"
```

Terraform plan

This is done with s secrets.tfvars file which should either remain locally on your computer or created/args fulfilled within a pipeline

```
terraform validate && terraform plan -var-file secrets.tfvars -out terraform.tfplan
```
