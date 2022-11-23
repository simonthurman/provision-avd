
param location string = resourceGroup().location

targetScope = 'resourceGroup'

resource newDesktopVirtualizationHostPool 'Microsoft.DesktopVirtualization/hostPools@2019-01-23-preview' = {
  name: 'myHostPool'
  location: location
  properties: {
    friendlyName: 'myHostPool'
    description: 'myHostPool'
    hostPoolType: 'Personal'
    loadBalancerType: 'BreadthFirst'
    personalDesktopAssignmentType: 'Automatic'
    maxSessionLimit: 9999
    preferredAppGroupType: 'Desktop'
    validationEnvironment: false
    vmTemplate: 'Windows10'
    customRdpProperty: 'full address:s:myHostPool.wvd.microsoft.com'
    registrationInfo: {
      expirationTime: '2020-01-01T00:00:00Z'
    }
  }
}

