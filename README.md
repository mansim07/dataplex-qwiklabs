# dataplex-qwiklabs

# Learning Objective

Dataset-level security controls(Using Dataplex)
Column-level security using Policy Tags
Row-level Security(native)
Metadata Management - Technical and business metadata
Data Classification and tagging
Data Security logging, auditing and monitoring
Data Quality 
Data Lineage 

## Load the customer data product


```
INSERT INTO
  `{PROJECT_ID}.customer_data_product.customer_data`
SELECT
  client_id AS client_id,
  ssn AS ssn,
  first_name AS first_name,
  NULL AS middle_name,
  last_name AS last_name,
  PARSE_DATE("%F",
    dob) AS dob,
    gender,
  [STRUCT('current' AS status,
    cdd.street AS street,
    cdd.city,
    cdd.state,
    cdd.zip AS zip_code,
    ST_GeogPoint(cdd.latitude,
      cdd.longitude) AS WKT,
    NULL AS modify_date)] AS address_with_history,
  [STRUCT(cdd.phonenum AS primary,
    NULL AS secondary,
    NULL AS modify_date)] AS phone_num,
  [STRUCT('current' AS status,
    cdd.email AS primary,
    NULL AS secondary,
    NULL AS modify_date)] AS email,
  customer_data.ingest_date AS ingest_date
  cc_number AS cc_number,
   cc_expiry AS cc_expiry,
   cc_provider AS cc_provider, 
   cc_ccv AS cc_ccv, 
   cc_card_type AS cc_card_type
    FROM
      `{PROJECT_ID}.customer_refined_data.{input_tbl_cust}` customer_data
      inner join 
      `{PROJECT_ID}.customer_refined_data.{input_tbl_cust}` cc_customer_data
    WHERE
      customer_data.ingest_date='{partition_date}' )
```

## Dataset level security (Using Dataplex )

## CLS 

## RLS 

# Data Quality and Tagging 

##  Data Classification and Tagging 

## Data Lineage 


