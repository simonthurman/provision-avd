param location string = resourceGroup().location
param appGroupRef string 

targetScope = 'resourceGroup'

//param appGroupReferences string
//var appGroupResources = array(resourceId('Microsoft.DesktopVirtualization/applicationGroups/', 'myApplicationGroup'))

//var appGroupRef = appGroupReferences == '' ? appGroupResources : concat(split(appGroupReferences, ','), appGroupResources)

resource newDesktopVirtualizationWorkspace 'Microsoft.DesktopVirtualization/workspaces@2019-01-23-preview' = {
  name: 'myWorkspace'
  location: location
  properties: {
    friendlyName: 'myWorkspace'
    description: 'myWorkspace'
    applicationGroupReferences: [
      appGroupRef
    ]
  }
}
