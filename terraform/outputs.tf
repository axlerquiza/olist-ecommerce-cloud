output "service_account_email" {
  value = google_service_account.pipeline.email
}

output "raw_dataset_id" {
  value = google_bigquery_dataset.raw.dataset_id
}

output "project_id" {
  value = var.project
}
