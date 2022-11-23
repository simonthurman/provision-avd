param location string = resourceGroup().location
param virtualMachineName string = 'myvm'
param vmSize string = 'Standard_DS1_v2'
param imagePublisher string = 'microsoftwindowsdesktop'
param imageOffer string = 'windows-11'
param imageSku string = 'win11-21h2-ent'
param imageVersion string = 'latest'
param storageAccountType string = 'Standard_LRS'
param adminUsername string = 'simont'
//@secure()
param adminPassword string = 'P@ssw0rd1234'

targetScope = 'resourceGroup'

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: '${virtualMachineName}sa'
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
  properties: {}
}

resource pip 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: '${virtualMachineName}pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource securityGroup 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: '${virtualMachineName}nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'default-allow-rdp'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
          protocol: 'Tcp'
        }
      }
    ]
  }
}


resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: '${virtualMachineName}vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: {
            id: securityGroup.id
          }
        }
      }
    ]
  }
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2022-05-01' = {
  name: '${virtualMachineName}nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetwork.name, 'default')
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: pip.id
          }
        }
      }
    ]
  }
}

resource newVirtualMachine 'Microsoft.Compute/virtualMachines@2019-07-01' = {
  name: virtualMachineName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: imageVersion
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: storageAccountType
        }
      }
    }
    osProfile: {
      computerName: virtualMachineName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: resourceId('Microsoft.Network/networkInterfaces', networkInterface.name)
        }
      ]
    }
  }
}

resource newVMDomainJoin 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  name: '${virtualMachineName}/DomainJoin'
  location: location
  properties: {
    publisher:'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
  dependsOn:[
    newVirtualMachine
  ]
}

resource newVMWinRM 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  name: '${virtualMachineName}/WinRM'
  location: location
  properties: {
    publisher:'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://github.com/simonthurman/provision-avd/blob/main/Configuration/'
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File Configure.ps1'
    }
  }
  dependsOn: [
    newVMDomainJoin
  ]
}
