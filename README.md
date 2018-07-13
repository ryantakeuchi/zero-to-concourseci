# Bootstrap a Control Plane

**THIS IS A WIP**

## Introduction

We will use the [bosh bootloader](https://github.com/cloudfoundry/bosh-bootloader) aka `bbl` to bootstrap our control plane.

At the end of this tutorial you should have a control plane consisting of:

* a new AWS VPC
* a bosh director
* Concourse CI cluster (optional)

There is a lot of cli tools required for a platform operator. To make this easier there is a Docker container, [aussielunix/boshtoolkit](https://hub.docker.com/r/aussielunix/boshtoolkit/), with all the tools required.

```bash
docker run -it --rm --user $(id -u):$(id -g) -v $(pwd):/workspace aussielunix/boshtoolkit /bin/bash
aws configure
aws s3 ls #should not error

```

## Create a bbl IAM user

Tune some settings in `setup/iam/terraform_create_iam_users.tf` and then run:
* `cd setup/iam`
* `terraform init`
* `terraform plan -out iam.plan`
* `terraform apply 'iam.plan'`

## Prepare your environment

``` bash
cp .envrc-example nonprod/.envrc
# Tune nonprod/.envrc using the new bbl user credentials from above
cd nonprod
direnv allow
```
Check this as it should not error.

``` bash
aws s3 ls
```

`bbl` has the concept of [plan-patches](https://github.com/cloudfoundry/bosh-bootloader/tree/master/plan-patches). This is a way of supplying terraform overrides. Patches belong in `nonprod/terraform`, `nonprod/cloud-config` or `nonprod/vars`  

We will be making use of one of these as an example.  

``` bash
cp ../plan-patches/aws-vpc-cidr/aws-vpc-cidr.tfvars vars/
```
**Be sure to tune these files**

## Prepare an AWS control plane

This will build a new VPC, subnets etc.  

* `bbl up`

You should now have a working bosh director in a new VPC.  
Load up your new environment variables.  

`direnv allow`  
Test you are able to connect to your new bosh director.  
`bosh env`
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
# :FIXME: - This needs to be redone

## Pivotal Concourse

We are now ready to deploy a Concourse CI to our director.  
Get some downloads from Pivnet and place them in the artifacts directory.

* grab concourse release from pivnet and check the sha256
* grab the latest AWS Stemcell from pivnet and check the sha256
* upload to director
```bash
  bosh upload-release ../artifacts/concourse-3.14.0.tgz
  bosh upload-stemcell ../artifacts/light-bosh-stemcell-3541.**-aws-xen-hvm-ubuntu-trusty-go_agent.tgz
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
* create an ELB for concourse
  * `bbl plan --lb-type=concourse`
  * `bbl up`
* Set the environment variable `$external_url` to the ELB address (no http/https)
* clone [concourse bosh deployment](https://github.com/concourse/concourse-bosh-deployment) and checkout the 3.14.0 tag
```
git clone git@github.com:concourse/concourse-bosh-deployment.git
git checkout tags/v3.14.0
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
fly -t pivotal-pas-pipelines login --concourse-url "http://$external_url"
```
* remember to frequently rotate these credentials
```bash
credhub regenerate --name /boshdirectorsname/concourse/atc_basic_auth
# and re-deploy concourse with the above bosh deploy...
```

