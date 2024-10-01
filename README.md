
# Terraform Enterprise Flexible Deployment Options - Active-Active mode on Docker (AWS)

This repository creates a new installation of TFE FDO in Active-Active mode on Docker (AWS)

# Diagram

WIP

# Prerequisites
+ Have Terraform installed as per the [official documentation](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)

+ AWS account

+ [AWS Key Pair](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html)

+ TFE FDO license

# How To

## Clone repository

```
git clone https://github.com/dmitryuchuvatov/tfe-fdo-docker-es-aa.git
```

## Change folder

```
cd tfe-fdo-docker-es-aa
```

## Create the file called `terraform.tfvars` and replace the values with your own
Example below:

```
aws_region       = "eu-west-2"
environment_name = "dmitry-test17"
vpc_cidr         = "10.200.0.0/16"
tfe_subdomain    = "dmitry-test17"
tfe_domain       = "tf-support.hashicorpdemo.com"
email            = "dmitry.uchuvatov@hashicorp.com"
instance_type    = "m5.xlarge"
pem_file         = "dmitry-test.pem"
key_pair         = "dmitry-test"
db_identifier    = "dmitry-docker"
db_name          = "fdo"
db_username      = "postgres"
db_password      = "Password1#"
enc_password     = "Password1#"
tfe_version      = "v202409-3"                        
tfe_license      = "02MV4U...."                                                                                                                                         
```
Make sure to copy your AWS Key Pair (in .pem format) to the repository root folder before moving forward

## Set AWS credentials

```
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
export AWS_SESSION_TOKEN=
```

## Terraform initialize

```
terraform init
```

## Terraform plan

```
terraform plan
```

## Terraform apply

```
terraform apply
```

When prompted, type **yes** and hit **Enter** to start provisioning AWS infrastructure and installing TFE FDO on it

You should see the similar result:

```
Apply complete! Resources: 36 added, 0 changed, 0 destroyed.

Outputs:

ssh_bastion = "ssh -i dmitry-test.pem ubuntu@18.169.27.218"
url = "https://dmitry-test17.tf-support.hashicorpdemo.com"

```

## Next steps

[Provision your first administrative user](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/initial-admin-user) and start using Terraform Enterprise.
