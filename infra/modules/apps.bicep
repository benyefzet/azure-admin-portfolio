// Apps for Kruszon - you write this module in weeks T8 (App Service) and T9 (containers). This file is only the plan.
//
// Goal: the order-status site runs on App Service with a staging slot; a containerised version runs on
// Azure Container Apps from an image in Azure Container Registry.
//
// AZ-104 skills covered: App Service plan and its scaling, web app, deployment slots, backup, networking
// settings, custom domain and TLS; ACR, Container Instances, Container Apps and their scaling.
//
// T8 steps:
//   1. Microsoft.Web/serverfarms (Linux). Work on F1 (free) and scale up to S1 only for slots and autoscale -
//      slots and autoscale need Standard or higher; delete or scale down when you finish.
//   2. Microsoft.Web/sites + a 'staging' slot (Microsoft.Web/sites/slots); swap them from the portal or CLI.
//   3. Regional VNet integration with network.outputs.appServiceSubnetId (virtualNetworkSubnetId).
//   4. Autoscale rule on the plan (CPU > 70 %), a backup from the portal, a custom domain only if you own one.
//
// T9 steps:
//   5. Microsoft.ContainerRegistry/registries, sku Standard (one Standard registry is free for 12 months
//      on a new account), admin user disabled.
//   6. Microsoft.App/managedEnvironments + Microsoft.App/containerApps pulling the image with a managed identity
//      that has the AcrPull role on the registry; scale rule: HTTP, 0-3 replicas.
//   7. One Azure Container Instances group from the CLI for comparison (then delete it).
//
// Reference: network.bicep (outputs consumed by other modules), storage.bicep (flags).
