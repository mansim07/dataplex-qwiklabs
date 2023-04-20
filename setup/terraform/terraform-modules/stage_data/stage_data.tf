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
variable "date_partition" {}
variable "customers_bucket_name" {}
variable "data_gen_git_repo" {}

####################################################################################
# Extract Data
####################################################################################

resource "null_resource" "run_datagen" {
  provisioner "local-exec" {
    command = <<-EOT
      cd ../resources/sample_data
      unzip -o synthetic_financial_data.zip
    EOT
    }
 
  }

resource "google_storage_bucket" "customer_storage_bucket" {
  project                     = var.project_id
  name                        = var.customers_bucket_name
  location                    = var.location
  force_destroy               = true
  uniform_bucket_level_access = true
  depends_on = [null_resource.run_datagen]
}


####################################################################################
# Create Customer GCS Objects
####################################################################################

resource "google_storage_bucket_object" "gcs_customers_objects" {
  for_each = {
    format("./resources/sample_data/customer.csv") : format("customers_data/dt=%s/customer.csv", var.date_partition),
    format("./resources/sample_data/cc_customer.csv") : format("cc_customers_data/dt=%s/cc_customer.csv", var.date_partition)
  }
  name        = each.value
  source      = each.key
  bucket = var.customers_bucket_name
  depends_on = [google_storage_bucket.customer_storage_bucket]
}

####################################################################################
# Create BigQuery Datasets
####################################################################################

resource "google_bigquery_dataset" "bigquery_datasets" {
  for_each = toset([ 
    "customer_data_product",
    "customer_private",
    "customer_ref_data",
    "customer_refined_data",
    "central_dlp_data",
   "central_audit_data",
   "central_dq_results"
  ])
  project                     = var.project_id
  dataset_id                  = each.key
  friendly_name               = each.key
  description                 = "${each.key} Dataset for Dataplex Demo"
  location                    = var.location
  delete_contents_on_destroy  = true
  depends_on = [google_storage_bucket_object.gcs_customers_objects]

}

####################################################################################
# Create BigQuery Customer Tables
####################################################################################

resource "random_integer" "jobid" {
  min     = 10
  max     = 100000
  keepers = {
    first = "${timestamp()}"
  }
  
}

resource "google_bigquery_job" "job" {
  for_each = {
    "customer_refined_data.mcc_code" : format("gs://%s/customers_data/dt=%s/customer.csv", var.customers_bucket_name, var.date_partition),
    "customer_refined_data.signature" : format("gs://%s/customers_data/dt=%s/cc_customer.csv", var.customers_bucket_name, var.date_partition),
  }
  job_id     = format("job_load_%s_${random_integer.jobid.result}", element(split(".", each.key), 1))
  project    = var.project_id
  location   = var.location
  #labels = {
  #  "my_job" ="load"
  #}

  load {
    source_uris = [
      each.value
    ]

    destination_table {
      project_id = var.project_id
      dataset_id = element(split(".", each.key), 0)
      table_id   = element(split(".", each.key), 1)
    }

    skip_leading_rows = 1
    schema_update_options = ["ALLOW_FIELD_RELAXATION", "ALLOW_FIELD_ADDITION"]

    write_disposition = "WRITE_APPEND"
    autodetect = true
    }

    depends_on  = [
                   google_bigquery_dataset.bigquery_datasets
                  ]
  }

  ####################################################################################
# Create some of the BQ tables so Dataplex discovery can register them as entities
####################################################################################

resource "google_bigquery_table" "customer_data_product" {
  dataset_id = "customer_data_product"
  table_id   = "customer_data"
  project    = var.project_id

  schema = <<EOF
[
  {
    "name": "client_id",
    "type": "STRING"
  },
  {
    "name": "ssn",
    "type": "STRING"
  },
  {
    "name": "first_name",
    "type": "STRING"
  },
  {
    "name": "middle_name",
    "type": "INTEGER"
  },
  {
    "name": "last_name",
    "type": "STRING"
  },
  {
    "name": "dob",
    "type": "DATE"
  },
  {
    "name": "gender",
    "type": "STRING"
  },
  {
    "fields": [
      {
        "name": "status",
        "type": "STRING"
      },
      {
        "name": "street",
        "type": "STRING"
      },
      {
        "name": "city",
        "type": "STRING"
      },
      {
        "name": "state",
        "type": "STRING"
      },
      {
        "name": "zip_code",
        "type": "INTEGER"
      },
      {
        "name": "WKT",
        "type": "GEOGRAPHY"
      },
      {
        "name": "modify_date",
        "type": "INTEGER"
      }
    ],
    "mode": "REPEATED",
    "name": "address_with_history",
    "type": "RECORD"
  },
  {
    "fields": [
      {
        "name": "primary",
        "type": "STRING"
      },
      {
        "name": "secondary",
        "type": "INTEGER"
      },
      {
        "name": "modify_date",
        "type": "INTEGER"
      }
    ],
    "mode": "REPEATED",
    "name": "phone_num",
    "type": "RECORD"
  },
  {
    "fields": [
      {
        "name": "status",
        "type": "STRING"
      },
      {
        "name": "primary",
        "type": "STRING"
      },
      {
        "name": "secondary",
        "type": "INTEGER"
      },
      {
        "name": "modify_date",
        "type": "INTEGER"
      }
    ],
    "mode": "REPEATED",
    "name": "email",
    "type": "RECORD"
  },
  {
    "name": "ingest_date",
    "type": "DATE"
  }
]

EOF

 depends_on = [google_bigquery_job.job]

}

resource "google_bigquery_table" "cc_customer_data_product" {
  dataset_id = "customer_data_product"
  table_id   = "cc_customer_data"
  project    = var.project_id

  schema = <<EOF
[
  {
    "name": "cc_number",
    "type": "INTEGER"
  },
  {
    "name": "cc_expiry",
    "type": "STRING"
  },
  {
    "name": "cc_provider",
    "type": "STRING"
  },
  {
    "name": "cc_ccv",
    "type": "INTEGER"
  },
  {
    "name": "cc_card_type",
    "type": "STRING"
  },
  {
    "name": "client_id",
    "type": "STRING"
  },
  {
    "name": "token",
    "type": "STRING"
  },
  {
    "name": "ingest_date",
    "type": "DATE"
  }
]
EOF
depends_on = [google_bigquery_job.job]

}


resource "google_bigquery_table" "merchant_data_product" {
  dataset_id = "merchants_data_product"
  table_id   = "core_merchants"
  project    = var.project_id

  schema = <<EOF
[
  {
    "name": "merchant_id",
    "type": "STRING"
  },
  {
    "name": "merchant_name",
    "type": "STRING"
  },
  {
    "name": "mcc",
    "type": "INTEGER"
  },
  {
    "name": "email",
    "type": "STRING"
  },
  {
    "name": "street",
    "type": "STRING"
  },
  {
    "name": "city",
    "type": "STRING"
  },
  {
    "name": "state",
    "type": "STRING"
  },
  {
    "name": "country",
    "type": "STRING"
  },
  {
    "name": "zip",
    "type": "STRING"
  },
  {
    "name": "latitude",
    "type": "FLOAT"
  },
  {
    "name": "longitude",
    "type": "FLOAT"
  },
  {
    "name": "owner_id",
    "type": "STRING"
  },
  {
    "name": "owner_name",
    "type": "STRING"
  },
  {
    "name": "terminal_ids",
    "type": "STRING"
  },
  {
    "name": "Description",
    "type": "STRING"
  },
  {
    "name": "Market_Segment",
    "type": "STRING"
  },
  {
    "name": "Industry_Code_Description",
    "type": "STRING"
  },
  {
    "name": "Industry_Code",
    "type": "STRING"
  },
  {
    "name": "ingest_date",
    "type": "DATE"
  }
]
EOF

depends_on = [google_bigquery_job.job]

}


resource "google_bigquery_table" "auth_data_product" {
  dataset_id = "auth_data_product"
  table_id   = "auth_table"
  project    = var.project_id

  time_partitioning {
    type = "DAY"
    field = "ingest_date"
  }


  schema = <<EOF
[
  {
    "name": "cc_token",
    "type": "STRING"
  },
  {
    "name": "merchant_id",
    "type": "STRING"
  },
  {
    "name": "card_read_type",
    "type": "INTEGER"
  },
  {
    "name": "entry_mode",
    "type": "STRING"
  },
  {
    "name": "trans_type",
    "type": "INTEGER"
  },
  {
    "name": "value",
    "type": "STRING"
  },
  {
    "name": "payment_method",
    "type": "INTEGER"
  },
  {
    "name": "pymt_name",
    "type": "STRING"
  },
  {
    "name": "swipe_code",
    "type": "INTEGER"
  },
  {
    "name": "swipe_value",
    "type": "STRING"
  },
  {
    "name": "trans_start_ts",
    "type": "TIMESTAMP"
  },
  {
    "name": "trans_end_ts",
    "type": "TIMESTAMP"
  },
  {
    "name": "trans_amount",
    "type": "STRING"
  },
  {
    "name": "trans_currency",
    "type": "STRING"
  },
  {
    "name": "trans_auth_code",
    "type": "INTEGER"
  },
  {
    "name": "trans_auth_date",
    "type": "FLOAT"
  },
  {
    "name": "origination",
    "type": "INTEGER"
  },
  {
    "name": "is_pin_entry",
    "type": "INTEGER"
  },
  {
    "name": "is_signed",
    "type": "INTEGER"
  },
  {
    "name": "is_unattended",
    "type": "INTEGER"
  },
  {
    "name": "event_ids",
    "type": "STRING"
  },
  {
    "name": "event",
    "type": "STRING"
  },
  {
    "name": "version",
    "type": "INTEGER"
  },
  {
    "name": "ingest_date",
    "type": "DATE"
  }
]
EOF

depends_on = [google_bigquery_job.job]

}