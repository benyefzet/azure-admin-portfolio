// Operations for Kruszon - you write this module in week T10. This file is only the plan.
//
// Goal: the team sees problems before customers do, and can restore a VM or fail over to West Europe.
//
// AZ-104 skills covered: metrics and logs in Azure Monitor, KQL queries, alert rules, action groups and
// alert processing rules, Insights, Network Watcher; Recovery Services vault vs Backup vault, backup policies,
// backup and restore, Site Recovery failover, backup reports and alerts.
//
// Steps:
//   1. Microsoft.OperationalInsights/workspaces (PerGB2018, 30-day retention, daily cap 0.1 GB) - the first
//      5 GB per month per billing account are free.
//   2. Diagnostic settings (Microsoft.Insights/diagnosticSettings) for the storage account and the load balancer.
//   3. Microsoft.Insights/actionGroups with your e-mail; an activity log alert for "Delete Virtual Machine";
//      a metric alert for VMSS CPU > 80 %; an alert processing rule that mutes alerts during a maintenance window.
//   4. Microsoft.RecoveryServices/vaults (LRS for the lab) + a daily VM backup policy. Before testing, disable
//      soft delete on this lab vault - otherwise deleted backup items block deleting the vault for 14 days.
//   5. Site Recovery to West Europe: configure from the portal, run a test failover, clean it up, disable
//      replication. Write the runbook (steps + screenshots) in docs/, not in Bicep.
//   6. queries.kql next to this file: heartbeat per VM, CPU over time, failed requests.
//
// Reference: network.bicep, storage.bicep.
