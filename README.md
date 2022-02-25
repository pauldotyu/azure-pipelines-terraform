# azure-pipeline-terraform

This repo will walk you through an approach to provisioning Azure resources using Terraform code stored in a Git repo and leveraging Azure (YAML-based) Pipelines to deploy to dev, test, and prod environments.

## Prerequisites

### Azure

> If you don't have Azure, go sign up for a [free account](https://azure.com/free) and come back.

Before you start, we will be using [Azure Storage as our Terraform remote backend](https://www.terraform.io/language/settings/backends/azurerm), so we'll need a new Azure storage account in each subscription where our environments will be deployed to.

To create your storage account, you can run the following Azure CLI command in [Azure Cloud Shell](https://shell.azure.com):

> This is just one example for one enviornment, so you will need to repeat this process for each environment you intend to deploy

```sh
# change this to your environment subscription name or guid
az account set -s "Application 1"

# change this to your environment name
env=dev

# choose a region to deploy into
location=westus

# resource group name with environment added to the end
rgname=rg-"terraform${env}"

# storage account name - make sure this value is globally unique within all of azure
stacct="saterraform${env}2022"

# storage container name
container="terraform${env}"

# create the resource group
az group create -n $rgname -l $location

# create the azure storage account
stname=$(az storage account create -g $rgname -n $stacct --query name -o tsv)

# create the blob container
az storage container create -n $container --account-name $stname --auth-mode login
```

Once you have the storage account created, make a note of all resource group, storage account, and container and create a backend config file for terraform. I put my storage account information in a file called `dev-backend.hcl`.

```text
resource_group_name  = "rg-terraformdev"
storage_account_name = "saterraformdev2022"
container_name       = "terraformdev"
key                  = "terraform.tfstate"
```

> Create a file for each environment as we will use these in our pipelines and save these files in a temp directory somewhere on your machine. These files will not be committed to your repo.

### Azure DevOps

If you do not already have an Azure DevOps organization, follow [these instructions](https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/create-organization?view=azure-devops) to create one.

If you do not already have an Azure DevOps project within an organziation, follow [these instructions](https://docs.microsoft.com/en-us/azure/devops/organizations/projects/create-project?view=azure-devops&tabs=preview-page) to create one.

Create a new Azure Repo within a project. If you are not sure how to create one, follow [these instructions](https://docs.microsoft.com/en-us/azure/devops/repos/git/create-new-repo?view=azure-devops).

Once you have a new empty repo created and cloned, you can move on to the next step.

> NOTE: Before moving forward, make sure you have a `.gitignore` file in your repo that is targeted toward omitting files that are related to Terraform but should not be committed to your repo. You should take my [.gitignore](./.gitignore) file as I have modified it so that we can commit some `*.tfvars` to the repo.

## Write some basic Terraform code

Create a new directory and drop in a `main.tf`. file.

Let's keep it simple, we'll only deploy resource groups into our dev, test, and prod environments. My initial file looks like this:

```terraform
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "name" {
  name     = var.name
  location = var.location
}
```

If you noticed, I am using [variables](https://www.terraform.io/language/values/variables) for the resource group name and location since this will be different based on the environment I am deploying into.

Let's go create a `variables.tf` file.

```terraform
variable "name" {
  type        = string
  description = "Resource group name"
}

variable "location" {
  type        = string
  description = "Region to deploy into"
}
```

When we execute the `terraform plan` command, terraform will expect values for these variables, so let's create a `dev.tfvars` and set our values for our dev environment. This file will be passed into terraform at runtime.

```terraform
name     = "rg-dev"
location = "westus"
```

> Create a file for each environment

We're nearly done with the terraform, we just need to create a `backend.tf` file to configure the azurerm remote backend.

```terraform
terraform {
  backend "azurerm" {}
}
```

> Notice that all we are saying above is that we want to use the `azurerm` backend provider. It is missing storage account details, but we will pass that in at runtime using the \*-backend.hcl files that we created above.

Finally, let's run a quick smoke test to make sure the code we wrote so far is valid and will not break during the Azure Pipeline runs. Back in the Azure Cloud Shell, run the following:

```sh
terraform init -backend-config="<YOUR_TEMP_DIR_PATH>/dev-backend.hcl"
terraform fmt
terraform validate
```

If you see the following message, we are good to go!

```text
Success! The configuration is valid.
```

> NOTE: Don't forget to commit and push your code to the remote repo!