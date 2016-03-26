﻿Function Invoke-PSDeploy {
    <#
    .SYNOPSIS
        Invoke PSDeploy

    .DESCRIPTION
        Invoke PSDeploy

        Searches for .PSDeploy.ps1 files in the current and nested paths, and invokes their deployment

        See Get-Help about_PSDeploy for more information.

    .PARAMETER Path
        Path to a specific PSDeploy.ps1 file, or to a folder that we recursively search for *.PSDeploy.ps1 files

        Defaults to the current path

    .PARAMETER Tags
        Only invoke deployments that are tagged with all of the specified Tags (-and, not -or)

    .PARAMETER DeploymentRoot
        Root path used to determing relative paths. Defaults to the current path.

    .PARAMETER PSDeployTypePath
        Specify a PSDeploy.yml file that maps DeploymentTypes to their scripts.

        This defaults to the PSDeploy.yml in the PSDeploy module folder

    .PARAMETER Force
        Force deployment, skipping prompts and confirmation

    .EXAMPLE
        Invoke-PSDeploy

        # Run deployments from any file named *.psdeploy.ps1 found under the current folder or any nested folders.
        # Prompts to confirm

    .EXAMPLE
        Invoke-PSDeploy -Path C:\Git\Module1\deployments\mymodule.psdeploy.ps1 -force

        # Run deployments from mymodule.psdeploy.ps1.
        # Don't prompt to confirm.

    .EXAMPLE
        Invoke-PSDeploy -Path C:\Git\Module1\deployments\mymodule.psdeploy.ps1 -DeploymentRoot C:\Git\Module1 -Tags Prod

        # Run deployments from mymodule.psdeploy.ps1.
        # Use C:\Git\Module1 to build any relative paths.
        # Only run deployments tagged 'Prod'

    .LINK
        about_PSDeploy

    .LINK
        https://github.com/RamblingCookieMonster/PSDeploy

    .LINK
        Deploy

    .LINK
        By

    .LINK
        To

    .LINK
        FromSource

    .LINK
        Tagged

    .LINK
        WithOptions

    .LINK
        DependingOn

    .LINK
        Get-PSDeployment

    .LINK
        Get-PSDeploymentType

    .LINK
        Get-PSDeploymentScript
    #>
    [cmdletbinding( SupportsShouldProcess = $True,
                    ConfirmImpact='High' )]
    Param(
        [parameter( ValueFromPipeline = $True,
                    ValueFromPipelineByPropertyName = $True)]
        [string[]]$Path = '.',

        [string]$DeploymentRoot,

        # Add later. Pass on to Invoke-PSDeployment.
        [validatescript({Test-Path -Path $_ -PathType Leaf -ErrorAction Stop})]
        [string]$PSDeployTypePath = $(Join-Path $PSScriptRoot PSDeploy.yml),

        [string[]]$Tags,

        [switch]$Force
    )
    Begin
    {
        # This script reads a deployment YML, deploys files or folders as defined
        Write-Verbose "Running Invoke-PSDeploy with ParameterSetName '$($PSCmdlet.ParameterSetName)' and params: $($PSBoundParameters | Out-String)"

        $RejectAll = $false
        $ConfirmAll = $false

        $DeploymentFiles = New-Object System.Collections.ArrayList

        $InvokePSDeploymentParams = @{}
        if($PSBoundParameters.ContainsKey('Confirm'))
        {
            $InvokePSDeploymentParams.add('Confirm',$Confirm)
        }
        if($PSBoundParameters.ContainsKey('Force'))
        {
            $InvokePSDeploymentParams.add('Force',$Force)
        }
        if($PSBoundParameters.ContainsKey('PSDeployTypePath'))
        {
            $InvokePSDeploymentParams.add('PSDeployTypePath',$PSDeployTypePath)
        }

        $TagParam = @{}
        if($PSBoundParameters.ContainsKey('Tags'))
        {
            $TagParam.Add('Tags',$Tags)
        }
    }
    Process
    {
        foreach( $PathItem in $Path )
        {
            # Create a map for deployments
            Try
            {
                # Debating whether to make this a terminating error.
                # Stop all deployments because one is misconfigured?
                # I'm going with Copy-Item precedent.
                # Not terminating, so try catch is superfluous. Feel free to make this strict...
                $DeploymentFiles.AddRange( @( Resolve-DeployScripts -Path $PathItem ) )
                if ($DeploymentFiles.count -gt 0)
                {
                    Write-Verbose "Working with $($DeploymentFiles.Count) deployment files:`n$($DeploymentFiles | Out-String)"
                }
                else
                {
                    Write-Warning "No *.PSDeploy.ps1 files found under '$PathItem'"
                }
            }
            Catch
            {
                Throw "Error retrieving deployments from '$PathItem':`n$_"
            }
        }

        # Parse
        $GetPSDeployParams = @{Path = $DeploymentFiles}
        if($PSBoundParameters.ContainsKey('Tags'))
        {
            $GetPSDeployParams.Add('Tags',$Tags)
        }
        #Resolve relative paths... Thanks Oisin! http://stackoverflow.com/a/3040982/3067642
        if($PSBoundParameters.ContainsKey('DeploymentRoot'))
        {
            $DeploymentRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DeploymentRoot)
            $GetPSDeployParams.Add('DeploymentRoot', $DeploymentRoot)
        }

        # Handle Dependencies
        Get-PSDeployment @GetPSDeployParams |
            Foreach-Object {
                $TheseParams = @{'DeploymentParameters' = @{}}
                if($_.DeploymentOptions.Keys.Count -gt 0)
                {
                    # Shoehorn Deployment Options into DeploymentParameters
                    # Needed if we support both yml and ps1 definitions...
                    $hash = @{$($_.DeploymentType) = $_.DeploymentOptions}
                    $TheseParams.DeploymentParameters = $hash
                }

                $_ | Invoke-PSDeployment @TheseParams @InvokePSDeploymentParams
            }
    }
}