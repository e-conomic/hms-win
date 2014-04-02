function Format-WebApplicationOutput () {
    Process {            
        [PSCustomObject]@{
            id = $_.applicationPool
            start = "start"            
            build  = "build"
            revision = "revision"
            docks = "docks"
            env = "env"
        }
    }
}

function Format-ProcessOutput () {
    Process {     
        $appPoolName = $_.applicationPool      
        $appPool = Get-Item "IIS:\AppPools\$appPoolName"

        $status = ''
        if ($appPool.state -eq "Started") { $status = 'running'} else { $status = 'stopped'}

        [PSCustomObject]@{
            id = $appPoolName
            pid = 0
            'start-time' = $_.StartTime
            cwd = $_.physicalPath         
            status = $status
        }
    }
}