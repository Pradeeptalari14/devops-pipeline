#!/bin/bash
set -e

echo "⚠️  WARNING: This will DESTROY all AWS resources!"
read -p "Type 'destroy' to confirm: " confirm

if [ "$confirm" != "destroy" ]; then
    echo "Aborted."
    exit 0
fi

cd terraform
echo "Destroying resources..."
terraform destroy -auto-approve

echo "✅ Cleanup complete!"
