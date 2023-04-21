/**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */



locals {
  _prefix = var.project_id
  _prefix_first_element           =  local._prefix #element(split("-", local._prefix), 0)
  _data_gen_git_repo              = "https://github.com/mansim07/datamesh-datagenerator"
  _metastore_service_name         = "metastore-service"
  _customers_bucket_name          = format("%s_customers_raw_data", local._prefix_first_element)
  _customers_curated_bucket_name  = format("%s_customers_curated_data", local._prefix_first_element)
  _transactions_bucket_name       = format("%s_transactions_raw_data", local._prefix_first_element)
  _transactions_curated_bucket_name  = format("%s_transactions_curated_data", local._prefix_first_element)
  _transactions_ref_bucket_name   = format("%s_transactions_ref_raw_data", local._prefix_first_element)
  _merchants_bucket_name          = format("%s_merchants_raw_data", local._prefix_first_element)
  _merchants_curated_bucket_name  = format("%s_merchants_curated_data", local._prefix_first_element)
  _dataplex_process_bucket_name   = format("%s_dataplex_process", local._prefix_first_element) 
  _dataplex_bqtemp_bucket_name    = format("%s_dataplex_temp", local._prefix_first_element) 
  _bucket_prefix                  = var.project_id
  _vpc_nm                          = "dataplex-default"
}

provider "google" {
  project = var.project_id
  region  = var.location
}


data "google_project" "project" {}

locals {
  _project_number = data.google_project.project.number
  _date_partition = formatdate("YYYY-MM-DD", timestamp())
}



/******************************************
1. Activate APIs - Data Storage Project
 *****************************************/
module "activate_service_apis" {
  source                      = "terraform-google-modules/project-factory/google//modules/project_services"
  project_id                     = var.project_id
  enable_apis                 = true

  activate_apis = [
    "orgpolicy.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "containerregistry.googleapis.com",
    "bigquery.googleapis.com", 
    "storage.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "dlp.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "bigquerydatatransfer.googleapis.com",
    "dataproc.googleapis.com",
    "dataflow.googleapis.com",
    "dataplex.googleapis.com",
    "datacatalog.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "composer.googleapis.com",
    "datapipelines.googleapis.com",
    "cloudscheduler.googleapis.com",
    "datalineage.googleapis.com",
    "metastore.googleapis.com",
    "bigquerydatapolicy.googleapis.com"
    ]

  disable_services_on_destroy = false
  
}

/******************************************
1. Uncomment the below for Argolis Else comment from line #63 - line#119
 *****************************************/

/*******************************************
Introducing sleep to minimize errors from
dependencies having not completed
********************************************/
resource "time_sleep" "sleep_after_activate_service_apis" {
  create_duration = "60s"

  depends_on = [
    module.activate_service_apis
  ]
}

/******************************************
2. Project-scoped Org Policy Relaxing
*****************************************/

resource "google_project_organization_policy" "bool-policies-ds" {
  for_each = {
    "compute.requireOsLogin" : false,
    "compute.disableSerialPortLogging" : false,
    "compute.requireShieldedVm" : false
  }
  project    = var.project_id
  constraint = format("constraints/%s", each.key)
  boolean_policy {
    enforced = each.value
  }

  depends_on = [
    time_sleep.sleep_after_activate_service_apis
  ]

}

resource "google_project_organization_policy" "list_policies-ds" {
  for_each = {
    "compute.vmCanIpForward" : true,
    "compute.vmExternalIpAccess" : true,
    "compute.restrictVpcPeering" : true
    "compute.trustedImageProjects" : true
    "iam.allowedPolicyMemberDomains" : true
  }
  project     = var.project_id
  constraint = format("constraints/%s", each.key)
  list_policy {
    allow {
      all = each.value
    }
  }

  depends_on = [
    time_sleep.sleep_after_activate_service_apis
  ]

}


##########################################################################################################
# This module runs the data generator, creates the gcs buckets and bq datasets and stages the data in the raw layer
##########################################################################################################

module "stage_data" {
  # Run this as the currently logged in user or the service account (assuming DevOps)
  source                                = "./terraform-modules/stage_data"
  project_id                            = var.project_id
  data_gen_git_repo                     = local._data_gen_git_repo
  location                              = var.location
  date_partition                        =  local._date_partition #var.date_partition
  customers_bucket_name                 = local._customers_bucket_name

depends_on = [
    google_project_organization_policy.list_policies-ds
  ]
}

#Done

####################################################################################
# Compute IAM Setup 
####################################################################################

module "iam_setup" {
  # Run this as the currently logged in user or the service account (assuming DevOps)
  source                                = "./terraform-modules/iam"
  project_id                            = var.project_id
  project_number                = var.project_number #local._project_number

  depends_on = [module.stage_data]
}

####################################################################################
# Stage the code artifacts 
# 1. Create the tag templates 
# 2. Copy all all dq configs and common libraries
####################################################################################

module "stage_code" {
 source                                = "./terraform-modules/stage_code"
 project_id                            = var.project_id
 location                              = var.location
 dataplex_process_bucket_name = local._dataplex_process_bucket_name
 dataplex_bqtemp_bucket_name = local._dataplex_bqtemp_bucket_name  
 
 depends_on = [module.iam_setup]

}


####################################################################################
# Organize the Data
####################################################################################
module "organize_data" {
  # Run this as the currently logged in user or the service account (assuming DevOps)
  source                 = "./terraform-modules/organize_data"
  #metastore_service_name = local._metastore_service_name
  project_id             = var.project_id
  location               = var.location
  lake_name              = var.lake_name
  project_number         = var.project_number #local._project_number
  datastore_project_id   = var.project_id
   
  depends_on = [module.stage_code]

}


####################################################################################
# Register the Data Assets in Dataplex
####################################################################################
module "register_assets" {
  # Run this as the currently logged in user or the service account (assuming DevOps)
  source                                = "./terraform-modules/register_assets"
  project_id                            = var.project_id
  project_number                        = var.project_number #local._project_number
  location                              = var.location
  lake_name                             = var.lake_name
  customers_bucket_name                 = local._customers_bucket_name
  datastore_project_id                  = var.project_id
 
  depends_on = [module.organize_data]

}


####################################################################################
# Resource for Network Creation                                                    #
# The project was not created with the default network.                            #
# This creates just the network/subnets we need.                                   #
####################################################################################

resource "google_compute_network" "default_network" {
  project                 = var.project_id
  name                    = "dataplex-default"
  description             = "Default network"
  auto_create_subnetworks = false
  mtu                     = 1460

  depends_on = [module.register_assets]
}


####################################################################################
# Resource for Subnet                                                              #
#This creates just the subnets we need                                             #
####################################################################################

resource "google_compute_subnetwork" "main_subnet" {
  project       = var.project_id
  name          = "dataplex-default"       #format("%s-misc-subnet", local._prefix)
  ip_cidr_range = var.ip_range
  region        = var.location
  network       = google_compute_network.default_network.id
  private_ip_google_access = true
  depends_on = [
    google_compute_network.default_network,
  ]
}

####################################################################################
# Resource for Firewall rule                                                       #
####################################################################################

resource "google_compute_firewall" "firewall_rule" {
  project  = var.project_id
  name     = "allow-intra-default"                    # format("allow-intra-%s-misc-subnet", local._prefix)
  network  = google_compute_network.default_network.id

  direction = "INGRESS"

  allow {
    protocol = "all"
  }
  
  source_ranges = [ var.ip_range ]
  depends_on = [
    google_compute_subnetwork.main_subnet
  ]
}

resource "google_compute_firewall" "user_firewall_rule" {
  project  = var.project_id
  name     = "allow-ingress-from-office-default"  #format("allow-ingress-from-office-%s", local._prefix)
  network  = google_compute_network.default_network.id

  direction = "INGRESS"

  allow {
    protocol = "all"
  }

  source_ranges = [ var.user_ip_range ]
  depends_on = [
    google_compute_subnetwork.main_subnet
  ]
}
