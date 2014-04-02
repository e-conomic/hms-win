
# Terminate script execution if we see an error
$ErrorActionPreference = "Stop"

Import-Module WebAdministration

function Build-Binding($port = "80", $runtimeVersion = "v4.0", $hostname = "") {
    return "*:${port}:$hostname"
}

function Running-Service($serviceName) {
    $appPoolPath = "IIS:\AppPools\$serviceName"
    
    if (!(Test-Path $appPoolPath)) {        
        return $false
    }
    else {            
        $appPool = Get-Item $appPoolPath
        if ($appPool.state -eq "Started") { 
            return $true
        } 
        else { 
            return $false
        }
    }
}

function Create-AppPool ($serviceName, $runtimeVersion = "v4.0") {    
    $appPoolUrl = "IIS:\AppPools\$serviceName"
    
    if (Test-Path $appPoolUrl) {
      return [PSCustomObject]@{
            message = "$appPoolUrl already exists";            
            status = 200
      }      
    }    
        
    $appPool = New-Item $appPoolUrl 
    $appPool.processModel.identityType = "NetworkService"
    $appPool.enable32BitAppOnWin64 = "True"  
    $appPool.managedRuntimeVersion = $runtimeVersion
    $appPool | Set-Item    

    return [PSCustomObject]@{
        message = "Created app pool: $appPoolUrl";
        status = 201            
    }          
}

function Create-ServiceFolder($serviceName, $serviceFolder) {
    if (!(Test-Path $serviceFolder)) {
        New-Item $serviceFolder -type Directory | Out-Null    
        $index = "$serviceFolder\index.html"        
        "<html><head></head><body>$serviceName added successfully</body></html>" | Out-File $index

        return [PSCustomObject]@{
            message = "created folder: $serviceFolder";
            status = 201
        }
    }

    return [PSCustomObject]@{
        message = "already there: $serviceFolder";
        status = 200     
    }
}

function Create-Service ($serviceName, $serviceFolder, $port = "81", $runtimeVersion = "v4.0", $protocol = "http", $hostname = "") {    
    Create-AppPool $serviceName $runtimeVersion       
    $serviceUrl = "IIS:\Sites\$serviceName"
    $message = ""
    
    Create-ServiceFolder $serviceName $serviceFolder    
    
    if (Test-Path $serviceUrl) {
        return [PSCustomObject]@{
            message = "$serviceUrl already exists";
            status = 200
        }          
    }        
    else {
        # create web site         
        $binding = Build-Binding $port $runtimeVersion $hostname
        $service = New-Item $serviceUrl -bindings @{protocol=$protocol;bindingInformation=$binding} -PhysicalPath $serviceFolder | Out-Null
        Set-ItemProperty $serviceUrl -Name applicationPool -Value $serviceName        
        $message = "Created service: $serviceUrl"

        return [PSCustomObject]@{
            message = $message;
            status = 201            
        }          
    }    
}

function Start-Service ($serviceName) {    
    if (Test-Path "IIS:\AppPools\$serviceName") {
        Start-WebAppPool $serviceName
        return [PSCustomObject]@{
            message = "Started app pool: $serviceName";
            status = 200
        }        
    }

    return [PSCustomObject]@{
        message = "App pool not found: $serviceName";
        status = 404
    }    
}

function Stop-Service($serviceName) {
    
    if (!(Test-Path "IIS:\AppPools\$serviceName")) {        
        return [PSCustomObject]@{
            message = "App pool not found: $serviceName";
            status = 404
        }        
    }

    # check if running    
    $appPool = Get-Item "IIS:\AppPools\$serviceName"
    if ($appPool.State -eq "Stopped") {
        return [PSCustomObject]@{
            message = "Already stopped app pool: $serviceName";
            status = 304
        }            
    }

    Stop-WebAppPool $serviceName
    return [PSCustomObject]@{
        message = "Stopped app pool: $serviceName";
        status = 200
    }
}

function Restart-Service ($serviceName) {                
    if (Test-Path "IIS:\AppPools\$serviceName") {
        if (!(Running-Service)) {
            Start-WebAppPool $serviceName
        }
        else {
            Restart-WebAppPool $serviceName        
        }
        
        return [PSCustomObject]@{
            message = "Restarted app pool: $serviceName";
            status = 200
        }        
    }

    return [PSCustomObject]@{
        message = "App pool not found: $serviceName";
        status = 404
    }    
}

function Remove-AppPool ($serviceName) {    
    $appPoolUrl = "IIS:\AppPools\$serviceName"    
    if (!(Test-Path $appPoolUrl)) {        
        return [PSCustomObject]@{
            message = "Not found....$appPoolUrl";
            status = 404            
        }
    }
    
    Remove-Item $appPoolUrl -Recurse
    return [PSCustomObject]@{
       message = "Deleted app pool....$appPoolUrl";
       status = 200            
    }
}

function Remove-ServiceFolder ($serviceName, $serviceFolder) {    
    if (Test-Path $serviceFolder) {        
        Remove-Item $serviceFolder -Recurse
        return [PSCustomObject]@{
            message = "Removed folder: $serviceFolder";
            status = 200            
        }
    }

    return [PSCustomObject]@{
        message = "Not found: $serviceFolder";
        status = 404            
    }
}

function Remove-Service ($serviceName, $serviceFolder) {    
    Remove-AppPool $serviceName
    Remove-ServiceFolder $serviceName $serviceFolder

    $serviceUrl = "IIS:\Sites\$serviceName"
    if (!(Test-Path $serviceUrl)) {
        return [PSCustomObject]@{
            message = "Not found: $serviceUrl"            
            status = 404
        }        
    }

    Remove-Item $serviceUrl -Recurse    
    return [PSCustomObject]@{
        message = "Deleted service: $serviceUrl";            
        status = 200
    }    
}

function List-Services () {            
    return Get-WebSite | Format-WebApplicationOutput
}

function List-Processes () {                
    return Get-WebSite | Format-ProcessOutput
}