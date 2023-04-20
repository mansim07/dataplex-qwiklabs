# Provisioning Automation

The following are instructions to provision the environment with Terraform. It takes approximately 5 minutes to complete the deployment.

## 1. Clone the repo

Launch Cloud Shell scoped to the project and paste and run the below-
```
git clone https://github.com/mansim07/dataplex-techcon23.git
```


## 2. Declare variables

Paste and run the below variables in Cloud Shell-
```
PROJECT_ID=`gcloud config list --format "value(core.project)" 2>/dev/null`
PROJECT_NBR=`gcloud projects describe $PROJECT_ID | grep projectNumber | cut -d':' -f2 |  tr -d "'" | xargs`
ORG_ID=`gcloud organizations list --format="value(name)"`
DATA_LOCATION="us-central1"
```

## 3. Initialize Terraform

Paste and run the below  in Cloud Shell-
```
cd ~/dataplex-techcon23/setup/terraform

terraform init
```

## 4. Review the Terraform deployment plan

Paste and run the below  in Cloud Shell-
```
terraform plan \
  -var="project_id=${PROJECT_ID}" \
  -var="project_number=${PROJECT_NBR}" \
  -var="org_id=${ORG_ID}" \
  -var="data_location=${DATA_LOCATION}"
  
```

## 5. Deploy with Terraform

Paste and run the below  in Cloud Shell-
```
terraform apply \
  -var="project_id=${PROJECT_ID}" \
  -var="project_number=${PROJECT_NBR}" \
  -var="org_id=${ORG_ID}" \
  -var="data_location=${DATA_LOCATION}"
  
```

This concludes the provisioning automation.