// azure-nettrace test environment
// A VNet-integrated App Service that talks to a private-endpoint SQL Server,
// plus a Key Vault. `breakScenario` intentionally injects one reachability
// defect so the skill's red-flag rules can be verified end to end.
//
// Deploy:  az deployment group create -g rg-nettrace-test -f main.bicep -p breakScenario=none
// Destroy: az group delete -n rg-nettrace-test --yes --no-wait

@description('Which reachability defect to inject (for validating red-flag rules).')
@allowed([
  'none'           // healthy baseline — expect 0 blockers
  'missingDnsLink' // omit private DNS VNet link            -> RF-04
  'denyNsg'        // NSG denies outbound 1433              -> RF-01
  'noPe'           // SQL public access off, no PE          -> RF-06
  'nvaRoute'       // 0.0.0.0/0 -> VirtualAppliance         -> RF-03
])
param breakScenario string = 'none'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Short unique suffix to avoid global-name collisions.')
param suffix string = uniqueString(resourceGroup().id)

@description('SQL admin login (test only).')
param sqlAdminLogin string = 'nettraceadmin'

@description('SQL admin password (test only). Pass at deploy time; never hardcode.')
@secure()
param sqlAdminPassword string

var vnetName = 'vnet-nettrace-${suffix}'
var appSubnetName = 'snet-appsvc'
var peSubnetName = 'snet-pe'
var nsgName = 'nsg-appsvc-${suffix}'
var routeTableName = 'rt-appsvc-${suffix}'
var planName = 'plan-nettrace-${suffix}'
var appName = 'app-nettrace-${suffix}'
var sqlServerName = 'sql-nettrace-${suffix}'
var sqlDbName = 'appdb'
var kvName = 'kv-nt-${suffix}'
var peName = 'pe-sql-${suffix}'
var dnsZoneName = 'privatelink${environment().suffixes.sqlServerHostname}'

// --- Conditionals derived from the chosen break scenario --------------------
var denyOutbound1433 = breakScenario == 'denyNsg'
var createPe = breakScenario != 'noPe'
var createDnsLink = breakScenario != 'missingDnsLink'
var useNvaRoute = breakScenario == 'nvaRoute'

// --- Network security group -------------------------------------------------
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: denyOutbound1433 ? [
      {
        name: 'DenySqlOutbound'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Deny'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '1433'
        }
      }
    ] : []
  }
}

// --- Route table (only meaningful in the nvaRoute scenario) -----------------
resource routeTable 'Microsoft.Network/routeTables@2024-05-01' = if (useNvaRoute) {
  name: routeTableName
  location: location
  properties: {
    routes: [
      {
        name: 'default-via-nva'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.20.9.4' // dummy NVA; not actually deployed
        }
      }
    ]
  }
}

// --- Virtual network + subnets ---------------------------------------------
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.20.0.0/16'] }
    subnets: [
      {
        name: appSubnetName
        properties: {
          addressPrefix: '10.20.1.0/24'
          networkSecurityGroup: { id: nsg.id }
          routeTable: useNvaRoute ? { id: routeTable.id } : null
          delegations: [
            {
              name: 'webapp'
              properties: { serviceName: 'Microsoft.Web/serverFarms' }
            }
          ]
        }
      }
      {
        name: peSubnetName
        properties: {
          addressPrefix: '10.20.2.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// --- App Service (VNet integrated) ------------------------------------------
resource plan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: planName
  location: location
  sku: { name: 'B1', tier: 'Basic' }
  kind: 'linux'
  properties: { reserved: true }
}

resource app 'Microsoft.Web/sites@2024-04-01' = {
  name: appName
  location: location
  kind: 'app,linux'
  properties: {
    serverFarmId: plan.id
    virtualNetworkSubnetId: '${vnet.id}/subnets/${appSubnetName}'
    vnetRouteAllEnabled: true
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|8.0'
      // Connection inference targets: an explicit SQL connection string
      // (password is a Key Vault reference, so no secret sits in app settings)
      // and a Key Vault reference.
      connectionStrings: [
        {
          name: 'AppDb'
          type: 'SQLAzure'
          connectionString: 'Server=tcp:${sqlServerName}${environment().suffixes.sqlServerHostname},1433;Database=${sqlDbName};Authentication=Active Directory Managed Identity;'
        }
      ]
      appSettings: [
        {
          name: 'KV_SECRET'
          value: '@Microsoft.KeyVault(SecretUri=https://${kvName}${environment().suffixes.keyvaultDns}/secrets/app-secret/)'
        }
      ]
    }
  }
  identity: { type: 'SystemAssigned' }
}

// --- SQL Server + DB (private endpoint target) ------------------------------
resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    publicNetworkAccess: 'Disabled' // private-only; reachability depends on PE + DNS
    minimalTlsVersion: '1.2'
  }
}

resource sqlDb 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: sqlServer
  name: sqlDbName
  location: location
  sku: { name: 'Basic', tier: 'Basic' }
}

// --- Private endpoint for SQL (skipped in noPe scenario) --------------------
resource pe 'Microsoft.Network/privateEndpoints@2024-05-01' = if (createPe) {
  name: peName
  location: location
  properties: {
    subnet: { id: '${vnet.id}/subnets/${peSubnetName}' }
    privateLinkServiceConnections: [
      {
        name: 'sqlConnection'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: ['sqlServer']
        }
      }
    ]
  }
}

// --- Private DNS zone + (conditional) VNet link + zone group ----------------
resource dnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (createPe) {
  name: dnsZoneName
  location: 'global'
}

resource dnsLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (createPe && createDnsLink) {
  parent: dnsZone
  name: 'link-${suffix}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: vnet.id }
  }
}

resource peDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (createPe) {
  parent: pe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'sql'
        properties: { privateDnsZoneId: dnsZone.id }
      }
    ]
  }
}

// --- Key Vault (dependency node for connection inference) -------------------
resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: kvName
  location: location
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    publicNetworkAccess: 'Enabled'
    networkAcls: { defaultAction: 'Allow', bypass: 'AzureServices' }
  }
}

// --- Outputs (names only; no secrets) ---------------------------------------
output appServiceName string = app.name
output sqlServerName string = sqlServer.name
output keyVaultName string = kv.name
output scenario string = breakScenario
output traceHint string = 'Run: trace the network connectivity of ${app.name}'
