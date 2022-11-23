$url1 = "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv"
$out1 = "$PSScriptRoot\RWrmXv.msi"
wget $url1 -outfile $out1

Start-Process -FilePath "$PSScriptRoot\RWrmXv.msi" -ArgumentList "/install" -Wait

$url2 = "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrxrH"
$out2 = "$PSScriptRoot\RWrxrH.msi"
wget $url2 -outfile $out2

Start-Process -FilePath "$PSScriptRoot\RWrxrH.msi" -ArgumentList "/install" -Wait