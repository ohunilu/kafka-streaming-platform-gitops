#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
OUTPUT_FILE="$PROJECT_ROOT/clusters/staging/secrets/orders-producer.enc.yaml"

NAMESPACE="customer-events"
SECRET_NAME="orders-producer-credentials"

BOOTSTRAP_SERVER="$(terraform -chdir="$TERRAFORM_DIR" output -raw kafka_bootstrap_endpoint)"
API_KEY="$(terraform -chdir="$TERRAFORM_DIR" output -raw orders_producer_api_key)"
API_SECRET="$(terraform -chdir="$TERRAFORM_DIR" output -raw orders_producer_api_secret)"

TEMP_FILE="$(mktemp)"

cleanup() {
    rm -f "$TEMP_FILE"
}

trap cleanup EXIT

cat > "$TEMP_FILE" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${NAMESPACE}
type: Opaque
stringData:
  bootstrap.servers: "${BOOTSTRAP_SERVER}"
  api.key: "${API_KEY}"
  api.secret: "${API_SECRET}"
EOF

mkdir -p "$(dirname "$OUTPUT_FILE")"

sops --encrypt \
    --input-type yaml \
    --output-type yaml \
    --filename-override "$OUTPUT_FILE" \
    "$TEMP_FILE" > "$OUTPUT_FILE"

chmod 600 "$OUTPUT_FILE"

echo "Encrypted Kafka credentials created:"
echo "$OUTPUT_FILE"