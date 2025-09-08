param subscriptionId string
param resourceGroup string
param location string
param azureFirewallName string = 'fw-hub'
param firewallPolicyName string = 'fw_hub_policy'
param vnetName string = 'vnet-hub'
param mgmtPublicIpName string = 'ip_fw_mgmt_hub'

var vnetId = resourceId(subscriptionId, resourceGroup, 'Microsoft.Network/virtualNetworks', vnetName)
var firewallPolicyId = resourceId(
  subscriptionId,
  resourceGroup,
  'Microsoft.Network/firewallPolicies',
  firewallPolicyName
)
var mgmtPublicIpId = resourceId(subscriptionId, resourceGroup, 'Microsoft.Network/publicIPAddresses', mgmtPublicIpName)

resource firewall 'Microsoft.Network/azureFirewalls@2024-07-01' = {
  name: azureFirewallName
  location: location
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Basic'
    }
    threatIntelMode: 'Alert'
    managementIpConfiguration: {
      name: 'mgmt-ip'
      properties: {
        publicIPAddress: {
          id: mgmtPublicIpId
        }
        subnet: {
          id: '${vnetId}/subnets/AzureFirewallManagementSubnet'
        }
      }
    }
    ipConfigurations: [
      {
        name: '${azureFirewallName}-ipconf'
        properties: {
          subnet: {
            id: '${vnetId}/subnets/AzureFirewallSubnet'
          }
        }
      }
    ]
    firewallPolicy: {
      id: firewallPolicyId
    }
  }
}
