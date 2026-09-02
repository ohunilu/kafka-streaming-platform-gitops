resource "confluent_environment" "staging" {
  display_name = var.environment_name

}

resource "confluent_kafka_cluster" "staging" {
  display_name = var.kafka_cluster_name
  availability = "SINGLE_ZONE"
  cloud        = "GCP"
  region       = var.kafka_region

  basic {}

  environment {
    id = confluent_environment.staging.id
  }

}

resource "confluent_service_account" "terraform_kafka_admin" {
  display_name = "terraform-kafka-admin"
  description  = "Service account used by Terraform to manage Kafka topics and ACLs"
}

resource "confluent_role_binding" "terraform_kafka_admin_cluster_admin" {
  principal   = "User:${confluent_service_account.terraform_kafka_admin.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.staging.rbac_crn
}

resource "confluent_api_key" "terraform_kafka_admin" {
  display_name = "terraform-kafka-admin-api-key"
  description  = "Kafka API key used by Terraform to manage Kafka resources"

  owner {
    id          = confluent_service_account.terraform_kafka_admin.id
    api_version = confluent_service_account.terraform_kafka_admin.api_version
    kind        = confluent_service_account.terraform_kafka_admin.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.staging.id
    api_version = confluent_kafka_cluster.staging.api_version
    kind        = confluent_kafka_cluster.staging.kind

    environment {
      id = confluent_environment.staging.id
    }
  }
}

resource "confluent_service_account" "orders_producer" {
  display_name = "orders-producer"
  description  = "Service account used by customer-events-producer to publish events to the orders topic"
}

resource "confluent_api_key" "orders_producer" {
  display_name = "orders-producer-kafka-api-key"
  description  = "Kafka API key for customer-events-producer"

  owner {
    id          = confluent_service_account.orders_producer.id
    api_version = confluent_service_account.orders_producer.api_version
    kind        = confluent_service_account.orders_producer.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.staging.id
    api_version = confluent_kafka_cluster.staging.api_version
    kind        = confluent_kafka_cluster.staging.kind

    environment {
      id = confluent_environment.staging.id
    }
  }

}

resource "confluent_kafka_topic" "orders" {
  kafka_cluster {
    id = confluent_kafka_cluster.staging.id
  }

  topic_name       = "orders"
  partitions_count = 3

  rest_endpoint = confluent_kafka_cluster.staging.rest_endpoint

  credentials {
    key    = confluent_api_key.terraform_kafka_admin.id
    secret = confluent_api_key.terraform_kafka_admin.secret
  }

  # Ensure API key AND role binding exist before creating the topic
  depends_on = [
    confluent_role_binding.terraform_kafka_admin_cluster_admin,
    confluent_api_key.terraform_kafka_admin
  ]

}

resource "confluent_kafka_acl" "orders_producer_write" {
  kafka_cluster {
    id = confluent_kafka_cluster.staging.id
  }

  resource_type = "TOPIC"
  resource_name = confluent_kafka_topic.orders.topic_name
  pattern_type  = "LITERAL"

  principal  = "User:${confluent_service_account.orders_producer.id}"
  host       = "*"
  operation  = "WRITE"
  permission = "ALLOW"

  rest_endpoint = confluent_kafka_cluster.staging.rest_endpoint

  credentials {
    key    = confluent_api_key.terraform_kafka_admin.id
    secret = confluent_api_key.terraform_kafka_admin.secret
  }

  depends_on = [
    confluent_role_binding.terraform_kafka_admin_cluster_admin,
    confluent_api_key.terraform_kafka_admin
  ]
}