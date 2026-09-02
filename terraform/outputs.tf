output "environment_id" {
  description = "Confluent Cloud environment ID"
  value       = confluent_environment.staging.id
}

output "kafka_cluster_id" {
  description = "Confluent Cloud Kafka cluster ID"
  value       = confluent_kafka_cluster.staging.id
}

output "kafka_bootstrap_endpoint" {
  description = "Kafka bootstrap endpoint"
  value       = confluent_kafka_cluster.staging.bootstrap_endpoint
}

output "kafka_rest_endpoint" {
  description = "Kafka REST endpoint"
  value       = confluent_kafka_cluster.staging.rest_endpoint
}

output "orders_topic" {
  description = "Kafka topic used by the customer events producer"
  value       = confluent_kafka_topic.orders.topic_name
}

output "orders_producer_service_account_id" {
  description = "Service account ID used by the orders producer"
  value       = confluent_service_account.orders_producer.id
}

output "orders_producer_api_key" {
  description = "Kafka API key for the orders producer"
  value       = confluent_api_key.orders_producer.id
  sensitive   = true
}

output "orders_producer_api_secret" {
  description = "Kafka API secret for the orders producer"
  value       = confluent_api_key.orders_producer.secret
  sensitive   = true
}

output "terraform_kafka_admin_api_key" {
  description = "Kafka API key used by Terraform to manage Kafka resources"
  value       = confluent_api_key.terraform_kafka_admin.id
  sensitive   = true
}

output "terraform_kafka_admin_api_secret" {
  description = "Kafka API secret used by Terraform to manage Kafka resources"
  value       = confluent_api_key.terraform_kafka_admin.secret
  sensitive   = true
}