#!/bin/bash

# Deployment script for Manufacturing Octopus Demo Environment
#
# This configuration creates its own dedicated "Manufacturing" space (see
# space.tf) as well as populating it — no separate space_id to provide, and
# it no longer shares the instance's default Spaces-1.

set -e

echo "🐙 Deploying Manufacturing Octopus Demo Environment"
echo "=============================================="

# Check for required variables
if [ -z "$OCTOPUS_SERVER_URL" ] || [ -z "$OCTOPUS_API_KEY" ]; then
    echo "❌ Error: Required environment variables not set"
    echo "Please set: OCTOPUS_SERVER_URL, OCTOPUS_API_KEY"
    exit 1
fi

# Initialize Terraform
echo "📦 Initializing Terraform..."
terraform init

# Validate configuration
echo "✅ Validating Terraform configuration..."
terraform validate

# Plan deployment
echo "📋 Planning deployment..."
terraform plan \
    -var="octopus_server_url=$OCTOPUS_SERVER_URL" \
    -var="octopus_api_key=$OCTOPUS_API_KEY" \
    -out=tfplan

# Apply if plan looks good
read -p "Apply this plan? (yes/no): " confirm
if [ "$confirm" == "yes" ]; then
    echo "🚀 Applying Terraform configuration..."
    terraform apply tfplan
    
    echo ""
    echo "✅ Deployment complete!"
    echo ""
    echo "📊 Demo Environment Summary:"
    terraform output demo_summary
    
    echo ""
    echo "🔗 Useful IDs for demo:"
    echo "Environments:"
    terraform output -json environment_ids | jq
    echo ""
    echo "Projects:"
    terraform output -json project_ids | jq
else
    echo "❌ Deployment cancelled"
    exit 0
fi