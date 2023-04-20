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

####################################################################################
# Variables
####################################################################################
variable "project_id" {}
variable "location" {}
variable "lake_name" {}
#variable "metastore_service_name" {}
variable "project_number" {}
variable "datastore_project_id" {}

/* With Metastore
resource "null_resource" "create_lake" {
 for_each = {
    "consumer-banking--customer--domain/Customer - Source Domain" : "domain_type=source",
    "consumer-banking--merchant--domain/Merchant - Source Domain" : "domain_type=source",
    "consumer-banking--creditcards--transaction--domain/Transactions - Source Domain" : "domain_type=source",
    "consumer-banking--creditcards--analytics--domain/Credit Card Analytics - Consumer Domain" : "domain_type=consumer",
    "central-operations--domain/Central Operations Domain" : "domain_type=operations"
  }
  provisioner "local-exec" {
    command = format("gcloud dataplex lakes create --project=%s %s --display-name=\"%s\" --location=%s --labels=%s --metastore-service=%s ", 
                     var.project_id,
                     element(split("/", each.key), 0),
                     element(split("/", each.key), 1),
                     var.location,
                     each.value,
                     "projects/${var.project_id}/locations/${var.location}/services/${var.metastore_service_name}")
  }
}
*/



####################################################################################
# Create Domain1: Customer Lakes and Zones                                                  #
####################################################################################

resource "google_dataplex_lake" "create_customer_lakes" {
  location     = var.location
  name         = "consumer-banking--customer--domain"
  description  = "Consumer Banking Customer Domain"
  display_name = "Consumer Banking - Customer Domain"

  labels       = {
    domain_type="source"
  }
  
  project = var.project_id
}

resource "google_dataplex_zone" "create_customer_zones" {
 for_each = {
    "customer-raw-zone/Customer Raw Zone/consumer-banking--customer--domain/RAW" : "data_product_category=raw_data",
    "customer-curated-zone/Customer Curated Zone/consumer-banking--customer--domain/CURATED" : "data_product_category=curated_data",
    "customer-data-product-zone/Customer Data Product Zone/consumer-banking--customer--domain/CURATED" : "data_product_category=master_data",
  }

  discovery_spec {
    enabled = true
    schedule = "0 * * * *"
  }

  lake     =  element(split("/", each.key), 2)
  location = var.location
  name     = element(split("/", each.key), 0)

  resource_spec {
    location_type = "SINGLE_REGION"
  }

  type         = element(split("/", each.key), 3)
  description  = element(split("/", each.key), 1)
  display_name = element(split("/", each.key), 1)
  labels       = {
    element(split("=", each.value), 0) = element(split("=", each.value), 1)
  }
  project      = var.project_id

  depends_on  = [google_dataplex_lake.create_customer_lakes]
}

####################################################################################
# Dataplex Service Account 
####################################################################################

resource "null_resource" "dataplex_permissions_1" {
  provisioner "local-exec" {
    command = format("gcloud projects add-iam-policy-binding %s --member=\"serviceAccount:service-%s@gcp-sa-dataplex.iam.gserviceaccount.com\" --role=\"roles/dataplex.dataReader\"", 
                      var.project_id,
                      var.project_number)
  }

  depends_on = [google_dataplex_zone.create_customer_zones]
}

resource "null_resource" "dataplex_permissions_2" {
  provisioner "local-exec" {
    command = format("gcloud projects add-iam-policy-binding %s --member=\"serviceAccount:service-%s@gcp-sa-dataplex.iam.gserviceaccount.com\" --role=\"roles/dataplex.serviceAgent\"", 
                      var.project_id,
                      var.project_number)
  }

  depends_on = [null_resource.dataplex_permissions_1]
}


# Delete the unnecessary dataset created in BigQuery only Zone based datasets 

resource "null_resource" "delete_empty_bq_ds" {
  provisioner "local-exec" {
    command = <<-EOT
    bq rm -r -f -d ${var.project_id}:customer_curated_zone
    bq rm -r -f -d ${var.project_id}:customer_data_product_zone
    EOT
    }
    depends_on = [null_resource.dataplex_permissions_2]

  }