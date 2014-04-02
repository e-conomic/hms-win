
# Load all modules
$gitModulePath = $PSScriptRoot + "\..\modules"
Get-ChildItem $gitModulePath | Get-Content | Out-String | Invoke-Expression

$mocked = "mocked"
$tempFolder = "c:\temp"

if (!(Test-Path $tempFolder)) {
    New-Item $tempFolder -type Directory
}

function Get-Unique () {
    $uniqueServiceName = [guid]::NewGuid().ToString()
    return $uniqueServiceName + "PESTER"
}

 
describe "Start-Service" {
    it "cannot start a service that does not exist" {           
        $uniqueServiceName = Get-Unique

        $result = Start-Service $uniqueServiceName
        $result.status | Should Be 404            
    }

    it "starts a service that exists" {        
        Mock Test-Path { return $true }
        Mock Start-WebAppPool {}

        $result = Start-Service $mocked
        $result.status | Should Be 200               
    }
}

describe "Running-Service" {
    it "will say service is not running if it does not exist" {        
        $result = Running-Service Get-Unique
        $result | Should Be $false
    }

    it "will say service is not running if it is not running" {
        Mock Test-Path { return $true }
        Mock Get-Item { return [PSCustomObject]@{ state = $false }} -Verifiable
        $result = Running-Service $mocked
        $result | Should Be $false
        Assert-VerifiableMocks
    }

    it "will say service is running if it is running" {        
        Mock Test-Path { return $true }        
        Mock Get-Item { return [PSCustomObject]@{ state = $true }} -Verifiable
        $result = Running-Service $mocked
        $result | Should Be $true
        Assert-VerifiableMocks
    }
}

describe "Create-AppPool" {
    it "will create the app pool if it does not exist" {
        $uniqueServiceName = Get-Unique
        $result = Create-AppPool $uniqueServiceName -Verifiable
        $result.status | Should Be 201
        Remove-AppPool $uniqueServiceName
        Assert-VerifiableMocks
    }

    it "will not create the app pool if it already exists" {
        Mock Test-Path { return $true }
        $result = Create-AppPool $mocked
        $result.status | Should Be 200
    }
}

describe "Create-ServiceFolder" {   
   it "will create it it does not exist" {        
        Remove-Item $tempFolder -Force -Recurse

        Mock Test-Path { return $false }
        
        $result = Create-ServiceFolder $mocked $tempFolder
        $result.status | Should Be 201         
        Assert-VerifiableMocks
   }     

   it "will not create if it already exists" {        
        Mock Test-Path { return $true }
        $result = Create-ServiceFolder $mocked $mocked
        $result.status | Should Be 200   
   }     
}

describe "Create-Service" {
    it "will create the service it does not exist" {
        $uniqueServiceName = Get-Unique
        $result = Create-Service $uniqueServiceName "$tempFolder\$uniqueServiceName"        
        $result.status | Should Be 201 
    }

    it "will not create the service if is already exists" {
        Mock Test-Path { return $true }
        $result = Create-Service $mocked $mocked
        $result.status | Should Be 200
    }
}

describe "Start-Service" {
    it "cannot start service if it does not exist" {
        $uniqueServiceName = Get-Unique
        $result = Start-Service $uniqueServiceName
        $result.status | Should Be 404
    }

    it "will start the service" {
        Mock Test-Path { return $true }
        Mock Start-WebAppPool {} -Verifiable
        $result = Start-Service $mocked
        $result.status | Should Be 200
        Assert-VerifiableMocks
    }
}

describe "Stop-Service" {
    it "cannot stop a service that does not exist" {
        $uniqueServiceName = Get-Unique
        $result = Stop-Service $uniqueServiceName
        $result.status | Should Be 404        
    }

    it "will not stop the service if not running" {
        Mock Test-Path { return $true }
        Mock Get-Item { return [PSCustomObject]@{ State = "Stopped" }}

        $result = Stop-Service $mocked
        $result.status | Should Be 304        
    }

    it "will stop the service if it is running" {
        Mock Test-Path { return $true }
        Mock Get-Item { return [PSCustomObject]@{ State = "Started" }}
        Mock Stop-WebAppPool {} -Verifiable

        $result = Stop-Service $mocked
        $result.status | Should Be 200
        Assert-VerifiableMocks
    }
}

describe "Restart-Service" {
    it "cannot restart a service that does not exist" {
        $uniqueServiceName = Get-Unique
        $result = Restart-Service $uniqueServiceName
        $result.status | Should Be 404           
    }

    it "restarts an existing service" {
        Mock Test-Path { return $true }
        Mock Running-Service { return $true }
        Mock Restart-WebAppPool {} -Verifiable

        $result = Restart-Service $mocked
        $result.status | Should Be 200
        Assert-VerifiableMocks
    }

    it "does not restart a service that is not running" {
        Mock Test-Path { return $true }
        Mock Running-Service { return $false }
        Mock Start-WebAppPool {} -Verifiable

        $result = Restart-Service $mocked
        $result.status | Should Be 200
        Assert-VerifiableMocks
    }
}

describe "Remove-AppPool" {
    it "cannot remove an app pool that does not exist" {
        $uniqueServiceName = Get-Unique
        $result = Remove-AppPool $uniqueServiceName
        $result.status | Should Be 404           
    }

    it "removes app pool" {
        Mock Test-Path { return $true }
        Mock Remove-Item {} -Verifiable

        $result = Remove-AppPool $mocked
        $result.status | Should Be 200
        Assert-VerifiableMocks
    }
}

describe "Remove-ServiceFolder" {
    it "cannot remove a folder that does not exist" {
        $uniqueServiceName = Get-Unique
        $result = Remove-ServiceFolder $uniqueServiceName "$temp\$uniqueServiceName"
        $result.status | Should Be 404              
    }

    it "removes folder" {
        Mock Test-Path { return $true }
        Mock Remove-Item {} -Verifiable

        $result = Remove-ServiceFolder $mocked "$temp\$mocked"
        $result.status | Should Be 200
        Assert-VerifiableMocks
    }
}

describe "Remove-Service" {
    it "cannot remove a service that does not exist" {
        $uniqueServiceName = Get-Unique
        $result = Remove-Service $uniqueServiceName "$tempFolder\$uniqueServiceName"
        $result.status | Should Be 404
    }
    it "removes service that exist" {
        $uniqueServiceName = Get-Unique
        
        Create-Service $uniqueServiceName "$tempFolder\$uniqueServiceName"
        $result = Remove-Service $uniqueServiceName "$tempFolder\$uniqueServiceName"
        $result.status | Should Be 200
    }
}

describe "List-Services" {
    it "includes newly created services" {
        $uniqueServiceName = Get-Unique
        Create-Service $uniqueServiceName $tempFolder        
        $result = List-Services
        
        $result[$result.length-1].id | Should Be $uniqueServiceName
    }
    it "does not include deleted service" {
        $uniqueServiceName = Get-Unique
        Create-Service $uniqueServiceName $tempFolder                
        Restart-Service $uniqueServiceName $tempFolder        
        $result = List-Services
        
        $result[$result.length-1].id | Should Be $uniqueServiceName
    }
}

describe "List-Processes" {
    it "includes newly created services" {
        $uniqueServiceName = Get-Unique
        Create-Service $uniqueServiceName "$tempFolder\$uniqueServiceName"        
        $result = List-Processes
        
        $result[$result.length-1].id | Should Be $uniqueServiceName
    }
    it "does not include deleted service" {
        $uniqueServiceName = Get-Unique
        Create-Service $uniqueServiceName "$tempFolder\$uniqueServiceName"                
        Remove-Service $uniqueServiceName "$tempFolder\$uniqueServiceName"        
        $result = List-Processes
        
        $result[$result.length-1].id | Should Not Be $uniqueServiceName
    }
}

describe "clean up services" {
    it "cleans up" {
        $services = List-Services | 
            Where-Object {($_.id.length -gt 20) -and ($_.id.Contains("PESTER"))} | 
            ForEach { Remove-Service $_.id "$temp\$_.id" }
    }
}