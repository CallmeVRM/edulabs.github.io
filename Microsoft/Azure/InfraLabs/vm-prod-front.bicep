// vm-prod-front.bicep
@description('Localisation des ressources')
param location string

@description('Nom de la machine virtuelle')
param VMName string

@description('Nom du groupe de ressources qui contient le VNet')
param vnetResourceGroup string

@description('ID complet du VNet existant')
param virtualNetworkId string

@description('Nom du subnet existant où placer la VM')
param subnetName string

@description('Nom du Network Interface à créer')
param networkInterfaceName string

@description('Nom d’utilisateur admin')
param adminUsername string

@secure()
@description('Mot de passe admin (secureString)')
param adminPassword string

@description('Taille de la VM')
param virtualMachineSize string = 'Standard_B1ms'

@description('Type de disque OS')
param osDiskType string = 'Premium_LRS'

@description('Zone de disponibilité (1, 2 ou 3 selon la région)')
param vmZone string = '1'

// ───────────────────────────────────────────────────────────
// Récupération du VNet et du subnet existants
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: last(split(virtualNetworkId, '/'))
  scope: resourceGroup(vnetResourceGroup)
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
  parent: vnet
  name: subnetName
}

// ───────────────────────────────────────────────────────────
// Création du Network Interface
resource nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: networkInterfaceName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

// ───────────────────────────────────────────────────────────
// Création de la machine virtuelle
resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: VMName
  location: location
  zones: [vmZone]
  properties: {
    hardwareProfile: {
      vmSize: virtualMachineSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'Debian'
        offer: 'debian-11'
        sku: '11'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
        deleteOption: 'Delete'
      }
    }
    osProfile: {
      computerName: VMName
      adminUsername: adminUsername
      adminPassword: adminPassword // ← valeur injectée par ARM
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}
