targetScope = 'subscription'

param resourceGroupName string
param location string

resource newResourceGroup 'Microsoft.Resources/resourceGroups@2018-05-01' = {
  name: resourceGroupName
  location: location
}

module newDesktopVirtualization 'HostPool.bicep' = {
  name: 'newDesktopVirtualization'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
  }
  dependsOn: [
    newResourceGroup
  ]
}

module newVirtualMachine 'VirtualMachine.bicep' = {
  name: 'newVirtualMachine'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
  }
  dependsOn: [
    newDesktopVirtualization
  ]
}

module newApplicationGroup 'ApplicationGroup.bicep' = {
  name: 'newApplicationGroup'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
  }
  dependsOn: [
    newDesktopVirtualization
  ]
}

module newWorkspace 'Workspace.bicep' = {
  name: 'newWorkspace'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    appGroupRef: '/subscriptions/c9eb6230-f475-4022-b04d-fe5a3d637812/resourcegroups/myRG/providers/Microsoft.DesktopVirtualization/applicationgroups/myApplicationGroup'
  }
  dependsOn: [
    newDesktopVirtualization
  ]
}
