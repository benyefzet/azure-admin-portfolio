// Compute for Kruszon - you write this module in week T7. This file is only the plan.
//
// Goal: the online store's web tier runs on a zone-redundant VM Scale Set behind the load balancer from T5.
//
// AZ-104 skills covered: create a VM, manage sizes and disks, availability zones vs availability sets,
// VM Scale Sets with autoscale, encryption at host, moving a VM to another resource group.
//
// Steps:
//   1. Parameters: location, env, tags, subnetId (network.outputs.webSubnetId), asgId (network.outputs.webAsgId),
//      lbBackendPoolId (from your T5 load balancer), adminUsername and a @secure() sshPublicKey.
//   2. Microsoft.Compute/virtualMachineScaleSets: Uniform orchestration, zones 1-3, Ubuntu LTS image,
//      sku Standard_B2ats_v2 (covered by the free-account hours), 2 instances, cloud-init that installs nginx.
//      Note: the built-in policy "Allowed virtual machine size SKUs" checks virtual machines only, not scale sets.
//   3. Microsoft.Insights/autoscalesettings: scale out by 1 when average CPU > 70 % for 10 minutes,
//      scale in by 1 when < 30 %, minimum 2, maximum 4.
//   4. Output the scale set name; call this module from infra/main.bicep behind a deployCompute flag
//      (copy the storage module pattern).
//   5. Portal-only exam tasks to practise on a single VM: resize, add and expand a data disk, enable
//      encryption at host, move the VM to another resource group. Delete it afterwards.
//
// Reference: network.bicep (loops, outputs), storage.bicep (flags, secure defaults).
