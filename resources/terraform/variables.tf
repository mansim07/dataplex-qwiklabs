variable "project_id" {
  type        = string
  description = "project id required"
}
variable "project_name" {
 type        = string
 description = "project name in which demo deploy"
}
variable "project_number" {
 type        = string
 description = "project number in which demo deploy"
}
variable "gcp_account_name" {
 description = "user performing the demo"
}
variable "deployment_service_account_name" {
 description = "Cloudbuild_Service_account having permission to deploy terraform resources"
}
variable "org_id" {
 description = "Organization ID in which project created"
}
variable "data_location" {
 type        = string
 description = "Location of source data file in central bucket"
}
variable "secret_stored_project" {
  type        = string
  description = "Project where secret is accessing from"
}

#############################################################
#Variables related to modules
#############################################################

###############################################################################################################################################
#Local declaration block is for the user to declare those variables here which is being used in .tf files in repetitive manner OR get the exact #definition from terraform document
###############################################################################################################################################
locals {
  # The project is the provided name OR the name with a random suffix

  #Commented below line @Mansi
  #local_project_id = var.project_number == "" ? "${var.project_id}-${random_string.project_random.result}" : var.project_id
  
  # Apply suffix to bucket so the name is unique
  #Commented below line @Mansi
  #local_storage_bucket = "${var.project_id}-${random_string.project_random.result}"
  
  # Use the GCP user or the service account running this in a DevOps process
  # local_impersonation_account = var.deployment_service_account_name == "" ? "user:${var.gcp_account_name}" : "serviceAccount:${var.deployment_service_account_name}"

}

############################################################################
#Variables which are required for running modules
############################################################################


variable "location" {
 description = "Location/region to be used"
 default = "us-central1"
}

variable "ip_range" {
 description = "IP Range used for the network for this demo"
 default = "10.6.0.0/24"
}

variable "hive_metastore_version" {
 description = "Version of hive to be used for the dataproc metastore"
 default = "3.1.2"
}

variable "lake_name" {
  description = "Default name of the Dataplex Lake"
  default = "dataplex_enablement_lake"
}

variable "user_ip_range" {
 description = "IP range for the user running the demo"
 default = "10.6.0.0/24"
}

#Dataplex-specific Regions 
