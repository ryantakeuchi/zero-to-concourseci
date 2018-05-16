# Bootstrap a Control Plane

**THIS IS A WIP**

## Introduction

We will use the [bosh bootloader](https://github.com/cloudfoundry/bosh-bootloader) aka `bbl` to bootstrap our control plane.

At the end of this tutorial you should have a control plane consisting of:

* a new AWS VPC
* a bosh director
* Concourse CI cluster (optional)
* a shared, remote `bbl` state and lock system (S3 & Dynamodb)

## Install Dependencies

**Linux tested only**

The following should be installed on your local machine:

* [bbl](https://github.com/cloudfoundry/bosh-bootloader/releases)
* [bosh-cli](https://bosh.io/docs/cli-v2.html)
* [bosh create-env dependencies](https://bosh.io/docs/cli-v2-install/#additional-dependencies)
* [terraform](https://www.terraform.io/downloads.html) >= 0.11.0
* [direnv](https://direnv.net/)
* an AWS IAM user with admin access

## Prepare the terraform S3 backend

Tune some names in `setup/terraform_s3_backend/terraform_s3_backend_provision.tf` then run:
* `cd setup/terraform_s3_backend`
* `terraform init`
* `terraform plan -out terraform_s3_backend_provision.plan`
* `terraform apply "terraform_s3_backend_provision.plan"`

## Create a bbl IAM user

Tune some settings in `setup/iam/terraform_create_iam_users.tf` and then run:
* `cd setup/iam`
* `vim terraform_create_iam_users.tf`
* `terraform init`
* `terraform plan -out iam.plan`
* `terraform apply 'iam.plan'`

## Prepare your environment

``` bash
mkdir nonprod
cp .envrc-example nonprod/.envrc
cd nonprod
# ignore direnv at this stage when prompted
# Tune .envrc using the new bbl user credentials from above
direnv allow
```
Check that your new aws credentials work and that your terraform backend S3 bucket exists.

``` bash
aws s3 ls
```

`bbl` has the concept of [plan-patches](https://github.com/cloudfoundry/bosh-bootloader/tree/master/plan-patches). This is a way of supplying terraform overrides.   

We will be making use of two of these as examples.  

``` bash
mkdir terraform
cp ../plan-patches/tf-backend-aws/terraform/s3_backend_override.tf terraform/
cp ../plan-patches/aws-vpc-cidr/aws-vpc-cidr.tfvars terraform/
```

Be sure to tune these files.  

## Prepare an AWS control plane

This will build a new VPC, subnets etc.  

* `bbl up"`

You should now have a working bosh director in a new VPC.  
Update your terminal's environment variables that are needed so your environment includes info on the new resources just built.

`direnv allow`
.
.
.
.
.
.
.
.
.
.
.
.
.
.
.
.
.
.
.
.
.
.
.
.
## Pivotal Concourse

We are now ready to deploy a Concourse CI to our director.  
Get some downloads from Pivnet and place them in the artifacts directory.

* grab concourse release from pivnet and check the sha256
* grab garden-runc from pivnet and check the sha256
* grab the latest AWS Stemcell from pivnet and check the sha256
* upload to director
```bash
  bosh upload-release ../artifacts/concourse-3.8.0.tgz
  bosh upload-release ../artifacts/garden-runc-1.9.0.tgz
  bosh upload-stemcell ../artifacts/light-bosh-stemcell-3468.27-aws-xen-hvm-ubuntu-trusty-go_agent.tgz
```
Credentials in credhub are namespaced like `/boshdirectorname/deploymentname/credname`
* find the bosh directors name
```bash
bbl outputs | grep director_name
```
* Generate some basic auth credentials for Concourse in Credhub.
```bash
credhub generate --type user --name /boshdirectorsname/concourse/atc_basic_auth
```
* Tune `manifests/settings.yml`
* Deploy concourse
```bash
bosh deploy -d concourse manifests/concourse.yml \
  -l manifests/versions.yml \
  --vars-store=cluster-creds.yml \
  --vars-file=manifests/settings.yml \
  -o manifests/operations/privileged-http.yml \
  -o manifests/operations/basic-auth.yml \
  -o manifests/operations/web-network-extension.yml \
  -o manifests/operations/worker-ephemeral-disk.yml
```
* retrieve the Concourse credentials and log in.
```bash
credhub get -n /boshdirectorsname/concourse/atc_basic_auth
```
* remember to frequently rotate these credentials
```bash
credhub regenerate --name /boshdirectorsname/concourse/atc_basic_auth
# and re-deploy concourse with the above bosh deploy...
```
