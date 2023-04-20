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
variable "project_number" {}
variable "location" {}
variable "lake_name" {}
variable "customers_bucket_name" {}
variable "datastore_project_id" {}


resource "google_dataplex_asset" "register_customer_gcs_asset" {
 for_each = {
    "customer-raw-data/Customer Raw Data/customer-raw-zone/consumer-banking--customer--domain" : var.customers_bucket_name,
  
  }
  name          = element(split("/", each.key), 0)
  display_name  = element(split("/", each.key), 1)
  location      = var.location

  lake = element(split("/", each.key), 3)
  dataplex_zone = element(split("/", each.key), 2)

  discovery_spec {
    enabled = true
    csv_options {
      delimiter = "|"
      header_rows = 1
    }
  }

  resource_spec {
    name = "projects/${var.datastore_project_id}/buckets/${each.value}"
    type = "STORAGE_BUCKET"
  }

  project = var.project_id

}

resource "google_dataplex_asset" "register_bq_assets1" {
 for_each = {
    #"customer-raw-data/Customer Raw Data/customer-raw-zone/consumer-banking--customer--domain" : var.customers_bucket_name,
    "customer-data-product/Customer Data Product/customer-data-product-zone/consumer-banking--customer--domain" : "customer_data_product",
    "customer-refined-data/Customer Refined Data/customer-curated-zone/consumer-banking--customer--domain" : "customer_refined_data"
  }
  name          = element(split("/", each.key), 0)
  display_name  = element(split("/", each.key), 1)
  location      = var.location

  lake = element(split("/", each.key), 3)
  dataplex_zone = element(split("/", each.key), 2)

  discovery_spec {
    enabled = true
  }

  resource_spec {
    name = "projects/${var.datastore_project_id}/datasets/${each.value}"
    type = "BIGQUERY_DATASET"
  }

  project = var.project_id
  depends_on  = [google_dataplex_asset.register_customer_gcs_asset]
}