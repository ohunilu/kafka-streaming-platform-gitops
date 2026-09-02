variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API key used by Terraform"
  type        = string
  sensitive   = true
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API secret used by Terraform"
  type        = string
  sensitive   = true
}

variable "environment_name" {
  description = "Name of the Confluent Cloud environment"
  type        = string
  default     = "kafka-streaming-platform-staging"
}

variable "kafka_cluster_name" {
  description = "Name of the Confluent Cloud Kafka cluster"
  type        = string
  default     = "kafka-streaming-staging"
}

variable "kafka_region" {
  description = "Confluent Cloud Kafka cluster region"
  type        = string
  default     = "us-east1"
}