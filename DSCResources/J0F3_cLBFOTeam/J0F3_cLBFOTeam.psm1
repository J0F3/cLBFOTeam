function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $TeamName,

        [parameter(Mandatory = $true)]
        [System.String[]]
        $TeamMembers

    )


    $Team = Get-NetLbfoTeam -Name "$TeamName" -ErrorAction SilentlyContinue


    $teaminfo = @{
    TeamName = $Team.Name
    Ensure = if($Team){'Present'}else{'Absent'}
    TeamMembers = $Team.Members
    TeamingMode = $Team.TeamingMode
    LBAlgorithm = $Team.LoadBalancingAlgorithm
    }

    return $teaminfo
    
}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $TeamName,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [parameter(Mandatory = $true)]
        [System.String[]]
        $TeamMembers,

        [ValidateSet("SwitchIndependent","Static","LACP")]
        [System.String]
        $TeamingMode = "SwitchIndependent",

        [ValidateSet("Dynamic","HyperVPort","TransportPorts","IPAddresses","MacAddresses")]
        [System.String]
        $LBAlgorithm = "HyperVPort"
    )

    switch ($Ensure)
    {
        'Present'
        {
        
            #Using the Get-TargetResource function to get properties of the team
            $teaminfo = Get-TargetResource -TeamName $TeamName -TeamMembers $TeamMembers

            # Check if team already exists. If yes not all setting are correct
            if($teaminfo.Ensure -eq 'Present')
            {

                Write-Verbose "Checking if Team members of $TeamName are correct..."
                if(!(Compare-Object -ReferenceObject $teaminfo.TeamMembers -DifferenceObject $TeamMembers -PassThru))
                {
                    Write-Verbose "Team $TeamName has the right team members configured"
                }
                else
                {
                    Write-Verbose "Team $TeamName has not the right team members configured"
                    Write-Verbose "Setting right team members..."
                    Compare-Object -ReferenceObject $teaminfo.TeamMembers -DifferenceObject $TeamMembers | 
                    foreach {if($_.SideIndicator -eq "=>"){Add-NetLbfoTeamMember -Team "$TeamName" -Name "$($_.InputObject)" -Confirm:$false}else{Remove-NetLbfoTeamMember -Team "$TeamName" -Name "$($_.InputObject)" -Confirm:$false}}
                }

                Write-Verbose "Checking if Team $TeamName has set the correct teaming mode..."
                if ($teaminfo.TeamingMode -eq $TeamingMode)
                {
                    Write-Verbose "Team $TeamName has set the correct teaming mode"    
                }
                else
                {
                    Write-Verbose "Team $TeamName has set an incorrect teaming mode ($($teaminfo.TeamingMode))"
                    Write-Verbose "Setting the teming mode to $TeamingMode..."  
                    Set-NetLbfoTeam -Name "$TeamName" -TeamingMode $TeamingMode -Confirm:$false
                }

                
                Write-Verbose "Checking if Team $TeamName has set the correct Load Balancing algorithm..."
                if ($teaminfo.LBAlgorithm -eq $LBAlgorithm)
                {
                    Write-Verbose "Team $TeamName has set the correct Load Balancing algorithm"
                }
                else
                {
                    Write-Verbose "Team $TeamName has set an incorrect Load Balancing algorithm ($($teaminfo.LBAlgorithm))"
                    Write-Verbose "Setting the Load Balancing algorithm to $LBAlgorithm..."  
                    Set-NetLbfoTeam -Name "$TeamName" -LoadBalancingAlgorithm $LBAlgorithm -Confirm:$false
                }
            }
            else
            {
                #Team not present. Just create new Team.
                $null = New-NetLbfoTeam -Name "$TeamName" -TeamMembers $TeamMembers -TeamingMode $TeamingMode -LoadBalancingAlgorithm $LBAlgorithm -Confirm:$false
            }
        
        }
    }        
                    
        'Absent'
        {
            #Ensure is set to Absent. Remove the team
            Get-NetLbfoTeam -Name "$TeamName" -ErrorAction SilentlyContinue | Remove-NetLbfoTeam       
        }
    }


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $TeamName,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [parameter(Mandatory = $true)]
        [System.String[]]
        $TeamMembers,

        [ValidateSet("SwitchIndependent","Static","LACP")]
        [System.String]
        $TeamingMode = "SwitchIndependent",

        [ValidateSet("Dynamic","HyperVPort","TransportPorts","IPAddresses","MacAddresses")]
        [System.String]
        $LBAlgorithm = "HyperVPort"
    )

     
    Write-Verbose -Message "Checking if NIC Team $TeamName is $Ensure..." 
    
    #Using the Get-TargetResource function to get properties of the team
    $teaminfo = Get-TargetResource -TeamName $TeamName -TeamMembers $TeamMembers

    # Check if team already exists
    if($teaminfo.Ensure -eq 'Present')
    {
        Write-Verbose -Message "NIC Team $TeamName is Present"
        #team is absent. But should it be present?
        if($Ensure -eq 'Present')
        {
            #team is present and shoud be present. OK. Lets check the config
            Write-Verbose "Checking if Team members of $TeamName are correct..."
            if(!(Compare-Object -ReferenceObject $teaminfo.TeamMembers -DifferenceObject $TeamMembers -PassThru))
            {
                Write-Verbose "Team members of $TeamName are correct"
            }
            else
            {
                #team members are NOT correct ($teaminfo.TeamMembers and $TeamMembers are different)
                return $false
            }

            Write-Verbose "Checking if Team $TeamName has set the correct teaming mode..."
            if ($teaminfo.TeamingMode -eq $TeamingMode)
            {
                Write-Verbose "Team $TeamName has set the correct teaming mode"    
            }
            else
            {
                #Teaming mode is incorrect
                return $false   
            }

            
            Write-Verbose "Checking if Team $TeamName has set the correct Load Balancing algorithm..."
            if ($teaminfo.LBAlgorithm -eq $LBAlgorithm)
            {
                Write-Verbose "Team $TeamName has set the correct Load Balancing algorithm"
            }
            else
            {
                #Teaming mode is incorrect
                return $false   
            }
            return $true
        }
        else
        {
            #team is present but should be absent. NOK
            return $false
        }
    }
    #team is abesent
    else
    {
        Write-Verbose -Message "NIC Team $TeamName is Absent"
        #team is absent. But should it be present?
        if($Ensure -eq 'Present')
        {
            #team is absent but shoud be present. NOK
            return $false
        }
        else
        {
            #team is absent and sould be absent. OK
            return $true
        }
    }
}


Export-ModuleMember -Function *-TargetResource

