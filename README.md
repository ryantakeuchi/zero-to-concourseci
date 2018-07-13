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
* `cd /workspace/setup/iam`
* `terraform init`
* `terraform plan -out iam.plan`
* `terraform apply 'iam.plan'`

## Prepare your environment

``` bash
cd /workspace/nonprod/
cp .envrc-example .envrc
# Tune nonprod/.envrc using the new bbl user credentials from above
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

## Pivotal Concourse

We are now ready to deploy a Concourse CI to our director.  
Get some downloads from Pivnet and place them in the `artifacts/` directory.

* cd ../artifacts/
* `pivnet login --api-token='my-api-token'`
* Download the ConcourseCI release from pivnet
  * `pivnet releases -p p-concourse` # note the latest version
  * `pivnet product-files -p p-concourse -r 3.13.0` # take note of the id's of the files
  * `pivnet download-product-files -p p-concourse -r 3.13.0 -i 151940`
* Download garden-runC release from pivnet
  * `pivnet download-product-files -p p-concourse -r 3.13.0 -i 151948`
* Download a compatible stemcell from pivnet
  * `pivnet releases -p stemcells`
  * `pivent product-files -p stemcells -r 3541.34`
  * `pivnet download-product-files -p stemcells -r 3541.34 -i 161596`
* upload these to your new bosh director
```bash
  cd ../nonprod
  bosh upload-release ../artifacts/concourse-3.13.0.tgz
  bosh upload-release ../artifacts/garden-runc-release-1.13.1.tgz
  bosh upload-stemcell ../artifacts/light-bosh-stemcell-3541.**-aws-xen-hvm-ubuntu-trusty-go_agent.tgz
```

Credentials in credhub are namespaced like `/boshdirectorname/deploymentname/credname`

* find the bosh directors name
```bash
bbl outputs | grep director_name
```
* Generate some basic auth credentials for Concourse in Credhub.
```bash
credhub generate --type user --username admin --name /boshdirectorsname/controlplane/atc_basic_auth
```
* create an ELB for concourse
  * `bbl plan --lb-type=concourse`
  * `bbl up`
* clone [concourse bosh deployment](https://github.com/concourse/concourse-bosh-deployment) and checkout the 3.14.0 tag
```
cd ../
git clone https://github.com/concourse/concourse-bosh-deployment
cd concourse-bosh-deployment
git checkout tags/v3.13.0
cd ../nonprod
```
* Tune `concourse/settings.yml`
* Deploy a concourse cluster
``` bash
bosh deploy -d controlplane \
  ../concourse-bosh-deployment/cluster/concourse.yml \
  -l ../concourse-bosh-deployment/versions.yml \
  --vars-store=cluster-cres.yml \
  --vars-file=concourse/settings.yml \
  -o ../concourse-bosh-deployment/cluster/operations/privileged-http.yml \
  -o ../concourse-bosh-deployment/cluster/operations/basic-auth.yml \
  -o ../concourse-bosh-deployment/cluster/operations/web-network-extension.yml \
  -o ../concourse-bosh-deployment/cluster/operations/worker-ephemeral-disk.yml
```
* retrieve the Concourse credentials and log in.
```bash
credhub get -n /boshdirectorsname/controlplane/atc_basic_auth
fly -t pivotal-pas-pipelines login --concourse-url "http://$external_url"
```
* remember to frequently rotate these credentials
```bash
credhub regenerate --name /boshdirectorsname/controlplane/atc_basic_auth
# and re-deploy concourse with the above bosh deploy...
```

