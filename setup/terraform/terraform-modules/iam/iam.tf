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


####################################################################################
# Create the Customer  service account for each data domain
####################################################################################
resource "google_service_account" "data_service_account" {
  project      = var.project_id
   for_each = {
    "customer-sa" : "customer-sa",
    "cls-pii-noaccess":"cls-pii-noaccess",
    "cls-pii-lastfour":"cls-pii-lastfour",
    "cls-pii-null":"cls-pii-null",
    "rls-user1":"rls-user1",
    "rls-user2":"rls-user2"
    }
  account_id   = format("%s", each.key)
  display_name = format("Demo Service Account %s", each.value)

}

####################################################################################
# Assign IAM Roles to the above service account. 
# We will use Dataplex for managing Data Security. This module is for compute only.  
####################################################################################

resource "google_project_iam_member" "iam_customer_sa" {
  for_each = toset([
"roles/iam.serviceAccountUser",
"roles/iam.serviceAccountTokenCreator",
"roles/serviceusage.serviceUsageConsumer",
"roles/bigquery.jobUser",
"roles/dataflow.worker",
"roles/dataplex.developer",
"roles/dataplex.metadataReader",
"roles/dataplex.metadataWriter",
"roles/metastore.metadataEditor",
"roles/metastore.serviceAgent",
"roles/dataproc.worker",
"roles/cloudscheduler.jobRunner",
"roles/dataplex.viewer",
"roles/datacatalog.tagEditor",
"roles/bigquery.readSessionUser"
])
  project  = var.project_id
  role     = each.key
  member   = format("serviceAccount:customer-sa@%s.iam.gserviceaccount.com", var.project_id)

  depends_on = [
    google_service_account.data_service_account
  ]

}

resource "google_project_iam_member" "iam_cls_pii_no_access_user" {
  for_each = toset([
"roles/iam.serviceAccountUser",
"roles/iam.serviceAccountTokenCreator",
"roles/serviceusage.serviceUsageConsumer",
"roles/bigquery.jobUser"
])
  project  = var.project_id
  role     = each.key
  member   = format("serviceAccount:cls-pii-noaccess@%s.iam.gserviceaccount.com", var.project_id)

  depends_on = [
    google_service_account.data_service_account
  ]

}


resource "google_project_iam_member" "iam_cls_pii_lastfour_user" {
  for_each = toset([
"roles/iam.serviceAccountUser",
"roles/iam.serviceAccountTokenCreator",
"roles/serviceusage.serviceUsageConsumer",
"roles/bigquery.jobUser"
])
  project  = var.project_id
  role     = each.key
  member   = format("serviceAccount:cls-pii-lastfour@%s.iam.gserviceaccount.com", var.project_id)

  depends_on = [
    google_service_account.data_service_account
  ]

}

resource "google_project_iam_member" "iam_cls_pii_null_user" {
  for_each = toset([
"roles/iam.serviceAccountUser",
"roles/iam.serviceAccountTokenCreator",
"roles/serviceusage.serviceUsageConsumer",
"roles/bigquery.jobUser"
])
  project  = var.project_id
  role     = each.key
  member   = format("serviceAccount:cls-pii-null@%s.iam.gserviceaccount.com", var.project_id)

  depends_on = [
    google_service_account.data_service_account
  ]

}

resource "google_project_iam_member" "iam_rls_user1" {
  for_each = toset([
"roles/iam.serviceAccountUser",
"roles/iam.serviceAccountTokenCreator",
"roles/serviceusage.serviceUsageConsumer",
"roles/bigquery.jobUser"
])
  project  = var.project_id
  role     = each.key
  member   = format("serviceAccount:rls-user1@%s.iam.gserviceaccount.com", var.project_id)

  depends_on = [
    google_service_account.data_service_account
  ]

}

resource "google_project_iam_member" "iam_rls_user2" {
  for_each = toset([
"roles/iam.serviceAccountUser",
"roles/iam.serviceAccountTokenCreator",
"roles/serviceusage.serviceUsageConsumer",
"roles/bigquery.jobUser",
])
  project  = var.project_id
  role     = each.key
  member   = format("serviceAccount:rls-user2@%s.iam.gserviceaccount.com", var.project_id)

  depends_on = [
    google_service_account.data_service_account
  ]

}

/*******************************************
Introducing sleep to minimize errors from
dependencies having not completed
********************************************/
resource "time_sleep" "sleep_after_network_and_iam_steps" {
  create_duration = "120s"
  depends_on = [
               google_project_iam_member.iam_customer_sa,
               google_project_iam_member.iam_cls_pii_no_access_user,
               google_project_iam_member.iam_cls_pii_lastfour_user,
               google_project_iam_member.iam_cls_pii_null_user,
               google_project_iam_member.iam_rls_user1,
               google_project_iam_member.iam_rls_user2
              ]
}


resource "google_bigquery_dataset_iam_binding" "dlp_writer" {
  dataset_id = "central_dlp_data"
  role       = "roles/bigquery.dataOwner"

  members = [
    format("serviceAccount:customer-sa@%s.iam.gserviceaccount.com", var.project_id)
  ]
depends_on = [
             time_sleep.sleep_after_network_and_iam_steps
              ]

}

resource "google_bigquery_dataset_iam_binding" "dq_writer" {
  dataset_id = "central_dq_results"
  role       = "roles/bigquery.dataOwner"

  members = [
    format("serviceAccount:customer-sa@%s.iam.gserviceaccount.com", var.project_id)
  ]

  depends_on = [
     google_bigquery_dataset_iam_binding.dlp_writer
               
              ]
}

resource "google_bigquery_dataset_iam_binding" "audit_writer" {
  dataset_id = "central_audit_data"
  role       = "roles/bigquery.dataOwner"

  members = [
    format("serviceAccount:customer-sa@%s.iam.gserviceaccount.com", var.project_id)
  ]
  depends_on = [
    google_bigquery_dataset_iam_binding.dq_writer
              
              ]
}

resource "google_bigquery_dataset_iam_binding" "cls_no_access_read" {
  dataset_id = "customer_refined_data"
  role       = "roles/bigquery.dataViewer"

  members = [
    format("serviceAccount:cls-pii-noaccess@%s.iam.gserviceaccount.com", var.project_id)
  ]
  depends_on = [
                google_bigquery_dataset_iam_binding.audit_writer
              ]
}

resource "google_bigquery_dataset_iam_binding" "cls_null_read" {
  dataset_id = "customer_refined_data"
  role       = "roles/bigquery.dataViewer"

  members = [
    format("serviceAccount:cls-pii-null@%s.iam.gserviceaccount.com", var.project_id)
  ]
  depends_on = [
                google_bigquery_dataset_iam_binding.cls_no_access_read
              ]
}


resource "google_bigquery_dataset_iam_binding" "cls_pii_lastfour_read" {
  dataset_id = "customer_refined_data"
  role       = "roles/bigquery.dataViewer"

  members = [
    format("serviceAccount:cls-pii-lastfour@%s.iam.gserviceaccount.com", var.project_id)
  ]
  depends_on = [
                google_bigquery_dataset_iam_binding.cls_null_read
              ]
}

resource "google_bigquery_dataset_iam_binding" "rls_user1_read" {
  dataset_id = "customer_refined_data"
  role       = "roles/bigquery.dataViewer"

  members = [
    format("serviceAccount:rls-user1@%s.iam.gserviceaccount.com", var.project_id)
  ]
  depends_on = [
                google_bigquery_dataset_iam_binding.cls_pii_lastfour_read
              ]
}


resource "google_bigquery_dataset_iam_binding" "rls_user2_read" {
  dataset_id = "customer_refined_data"
  role       = "roles/bigquery.dataViewer"

  members = [
    format("serviceAccount:rls-user2@%s.iam.gserviceaccount.com", var.project_id)
  ]
  depends_on = [
                google_bigquery_dataset_iam_binding.rls_user1_read
              ]
}


