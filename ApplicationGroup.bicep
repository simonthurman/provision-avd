param location string = resourceGroup().location

targetScope = 'resourceGroup'

resource newDesktopVirtualizationApplicationGroup 'Microsoft.DesktopVirtualization/applicationGroups@2019-01-23-preview' = {
  name: 'myApplicationGroup'
  location: location
  properties: {
    friendlyName: 'myApplicationGroup'
    description: 'myApplicationGroup'
    hostPoolArmPath: resourceId('Microsoft.DesktopVirtualization/hostPools', 'myHostPool')
    applicationGroupType: 'Desktop'
  }
}

