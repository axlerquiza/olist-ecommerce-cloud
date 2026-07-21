variable "project" {
  description = "GCP project id (created out-of-band, see README Step 0)"
  type        = string
}

variable "region" {
  description = "Default region for the google provider"
  type        = string
  default     = "us-central1"
}

variable "location" {
  description = "BigQuery dataset location"
  type        = string
  default     = "US"
}

variable "raw_dataset_id" {
  description = "BigQuery dataset dlt loads raw CSVs into"
  type        = string
  default     = "olist_raw"
}

variable "service_account_id" {
  description = "Service account id for the dlt/dbt pipeline"
  type        = string
  default     = "olist-pipeline"
}
