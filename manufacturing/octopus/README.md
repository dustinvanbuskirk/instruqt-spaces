# Manufacturing Octopus Deploy Demo Environment

This Terraform configuration creates a complete Octopus Deploy demo environment for Manufacturing, including:

- A dedicated "Manufacturing" space
- 3 Environments (SQA, UAT, Production)
- 15 Tenants (Fab facilities)
- 3 Projects (Photo Overlay Server, Data Pipeline, Probe OQC ADC)
- 2 Lifecycles (Manufacturing, Engineering)
- Tenant tags and connections
- Channels for release management

## Prerequisites

1. Octopus Deploy instance (Cloud or Self-Hosted)
2. Terraform >= 1.0
3. Octopus Deploy API key with appropriate permissions
4. jq (optional, for formatted output)

This configuration creates its own dedicated "Manufacturing" space
(`space.tf`) as well as populating it with environments, projects, tenants,
lifecycles, and channels — it no longer assumes or defaults to `Spaces-1`,
the instance's shared default space, and there's no separate space to
create beforehand.

## Setup

### Option 1: Using Environment Variables (Recommended)

1. Set environment variables:
```bash
export OCTOPUS_SERVER_URL="https://your-instance.octopus.app"
export OCTOPUS_API_KEY="API-XXXXXXXXXXXXXXXXXXXXXXXX"
```

2. Run the deployment script:
```bash
chmod +x deploy.sh
./deploy.sh
```

### Option 2: Using terraform.tfvars

1. Copy the example file:
```bash
cp terraform.tfvars.example terraform.tfvars
```

2. Edit `terraform.tfvars` with your actual values:
```hcl
octopus_server_url = "https://your-instance.octopus.app"
octopus_api_key    = "API-XXXXXXXXXXXXXXXXXXXXXXXX"
```

3. Initialize and apply:
```bash
terraform init
terraform plan
terraform apply
```

## Configuration

### Tenants Created

**Production Tenants (All Environments):**
- Fab 10N, Fab 10W
- Fab 11 (Lead Site)
- Fab 15, Fab 16, Fab 16S
- Fab 4, Fab 6
- MMP, MMY, MSB, MSI, MTB, MXA

**Testing Tenant:**
- MMT SQA (SQA only)

### Projects Created

1. **Photo Overlay Server**
   - Tenanted deployment
   - Connected to: Fab 10N, Fab 11, Fab 15, Fab 16, MMP
   - Manufacturing lifecycle with approvals
   - Channels: Stable (default), Beta

2. **Data Pipeline**
   - Non-tenanted (central deployment)
   - Engineering lifecycle (high frequency)

3. **Probe OQC ADC**
   - Tenanted deployment
   - Connected to: Fab 10N, Fab 11, Fab 15
   - Pull deployment model

### Lifecycles

- **Manufacturing**: SQA → UAT → Production (with manual approvals)
- **Engineering**: SQA → UAT (optional) → Production (self-service)

### Tenant Tags

- **Region**: North America, Asia
- **FacilityType**: Production, Testing
- **Deployment**: LeadSite

## Deployment Processes

**IMPORTANT**: Deployment processes are not included in this Terraform configuration. They should be configured through the Octopus Deploy UI or using Config as Code after the infrastructure is created.

### Recommended Deployment Process for Photo Overlay Server:

1. **Manual Approval Step** (Production environment only)
   - Action Type: Manual Intervention
   - Instructions: Verify RFC approval, SQA sign-off, UAT validation, and lead site specification

2. **Deploy Helm Chart**
   - Action Type: Deploy Kubernetes Helm Chart
   - Package: photo-overlay-server
   - Release Name: `photo-overlay-#{Octopus.Tenant.Name | ToLower | Replace " " "-"}`
   - Namespace: manufacturing
   - Client Version: V3

3. **Verify Deployment Health**
   - Action Type: Run a kubectl Script
   - Script: Check pod readiness and status
   - Namespace: manufacturing

### Alternative Approaches:

- **Config as Code**: Version control your deployment processes in Git
- **Process Templates**: Create reusable templates for common deployment patterns
- **Step Templates**: Use community or custom step templates for complex operations

## Outputs

After applying the configuration, you can view the created resources:
```bash
# View all outputs
terraform output

# View specific output
terraform output space_id
terraform output environment_ids
terraform output tenant_ids
terraform output project_ids
```

## Customization

To customize the configuration:

1. Edit the relevant `.tf` files in the directory
2. Run `terraform plan` to preview changes
3. Run `terraform apply` to apply changes

## Clean Up

To remove all created resources:
```bash
terraform destroy
```

**WARNING**: This will permanently delete all resources created by this configuration.

## Troubleshooting

### Common Issues

1. **Provider not found**
   - Ensure you're using the correct provider source: `OctopusDeploy/octopusdeploy`
   - Run `terraform init -upgrade` to update providers

2. **Authentication errors**
   - Verify your API key has the correct permissions
   - Ensure the Space ID is correct

3. **Resource conflicts**
   - Check if resources with the same names already exist
   - Use unique names or delete conflicting resources

## Documentation

- [Octopus Terraform Provider](https://registry.terraform.io/providers/OctopusDeploy/octopusdeploy/latest/docs)
- [Octopus Multi-Tenancy](https://octopus.com/docs/tenants)
- [Octopus Lifecycles](https://octopus.com/docs/releases/lifecycles)
- [Octopus Deploy Documentation](https://octopus.com/docs)

## Support

For issues with this Terraform configuration, please refer to:
- [Terraform Provider Issues](https://github.com/OctopusDeploy/terraform-provider-octopusdeploy/issues)
- [Octopus Deploy Support](https://octopus.com/support)