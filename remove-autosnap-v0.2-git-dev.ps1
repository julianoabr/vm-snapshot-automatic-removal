#Requires -Version 5.1
#Requires -RunAsAdministrator  

<#
.Synopsis
   Delete snapshots with more than configured days
.DESCRIPTION
   Delete snapshots with more than x days and bypasses snapshots with specific string
.EXAMPLE
   Remove-SnapshotAuto -doNotRemoveString DNR3
.EXAMPLE
   Remove-SnapshotAuto -doNotRemoveString DNR10
.CREATEDBY
    Juliano Alves de Brito Ribeiro (find me at julianoalvesbr@live.com or https://github.com/julianoabr or https://youtube.com/@powershellchannel)
.VERSION INFO
    0.2
.VERSION NOTES
    git version
.VERY IMPORTANT
  Revelation 22
  12 “Look, I am coming soon! My reward is with me, and I will give to each person according to what they have done.
  13 I am the Alpha and the Omega, the First and the Last, the Beginning and the End.

#>
Clear-Host

#Validate if VMware.VimAutomation.Core Module is installed
##########################################################

$moduleExists = Get-Module -Name Vmware.VimAutomation.Core

if ($moduleExists){
    
    Write-Host "O Modulo Vmware.VimAutomation.Core já está carregado." -ForegroundColor White -BackgroundColor DarkGreen
    
}#if validate module
else{
    
    Write-Host -NoNewline "O Modulo Vmware.VimAutomation.Core não está carregado." -ForegroundColor DarkBlue -BackgroundColor White
    Write-Host -NoNewline " Preciso desse módulo para que o script funcione" -ForegroundColor DarkCyan -BackgroundColor White
    
    Import-Module -Name Vmware.VimAutomation.Core -WarningAction SilentlyContinue -ErrorAction Stop -Verbose
    
}#else validate module


############################################################################################################################
#PAUSE POWERSHELL

function Pause-PSScript
{

   Read-Host 'Press Enter to continue…' | Out-Null
}


############################################################################################################################
#Function DisplayStart-Sleep

function DisplayStart-Sleep ($totalSeconds)
{

$currentSecond = $totalSeconds

while ($currentSecond -gt 0) {
    
    Write-Host "O Script está rodando. Espere mais $currentSecond segundos..." -ForegroundColor White -BackgroundColor DarkGreen
    
    Start-Sleep -Seconds 1 # Pause for 1 second
    
    $currentSecond--
    }

Write-Host "Contagem regressiva concluída!. Vamos continuar..." -ForegroundColor White -BackgroundColor DarkBlue

}#end of Function Display Start-Sleep

############################################################################################################################
#function to view if variable is numeric

function isNumeric ($x) {
    $x2 = 0
    $isNum = [System.Int32]::TryParse($x, [ref]$x2)
    return $isNum
} #end function is Numeric

############################################################################################################################
#FUNCTION CONNECT TO VCENTER

function Connect-TovCenterServer
{
    [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateSet('Menu','Automatic')]
        $methodToConnect = 'Automatic',
        
                      
        [Parameter(Mandatory=$false,
                   Position=1)]
        [System.String[]]$vCServerList, 
                
       
        [Parameter(Mandatory=$false,
                   Position=2)]
        [ValidateSet('80','443')]
        [System.String]$port = '443',

        [Parameter(Mandatory=$false,
                   Position=3)]
        [System.String]$userName = 'Administrator@vsphere.local'

    )

#this password will be generated with other script called encryptpwd.ps1
$vCenterPWD = (Get-content "$env:SystemDrive\Temp\Pwd\administrator-encryptedpwd.txt") | ConvertTo-SecureString

$vCenterCred = New-Object -typename System.Management.Automation.PSCredential -argumentlist $userName,$vCenterPWD
           
foreach ($vCServer in $vCServerList){
        
    $Script:workingServer = $vCServer

    $vCentersConnected = $global:DefaultVIServers.Count

    If ($vCentersConnected -eq 0){
            
        Write-Host "You are not connected to any vCenter" -ForegroundColor DarkGreen -BackgroundColor White
            
    }#validate connected vCenters
    Else{
        
        Write-Host "You are connected to $vCentersConnected vCenter(s)" -ForegroundColor DarkGreen -BackgroundColor White

        Write-Host "I will disconnect to all vCenters" -ForegroundColor DarkGreen -BackgroundColor White
            
        Disconnect-VIServer -Server * -Confirm:$false -Force -Verbose -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            
    }#validate connected vCenters
       
}#end of Foreach

if ($methodToConnect -eq 'Automatic'){

    Write-Host "You selected automatic connection to vCenters" -ForegroundColor White -BackgroundColor Green
    
}#end of if method to connect
else{

    $workingLocationNum = ""
        
    $tmpWorkingLocationNum = ""
        
    $Script:WorkingServer = ""
        
    $i = 0

    #MENU SELECT VCENTER
    foreach ($vCServer in $vCServerList){
	   
        $vcServerValue = $vCServer
	    
        Write-Output "            [$i].- $vcServerValue ";	
	    
        $i++	
        
        }#end foreach	
        
        Write-Output "            [$i].- Exit this script ";

        while(!(isNumeric($tmpWorkingLocationNum)) ){
	        
            $tmpWorkingLocationNum = Read-Host "Type vCenter Number that you want to connect"
            
        }#end of while

        $workingLocationNum = ($tmpWorkingLocationNum / 1)

        if(($WorkingLocationNum -ge 0) -and ($WorkingLocationNum -le ($i-1))  ){
	        
            $Script:WorkingServer = $vcServerList[$WorkingLocationNum]
        
        }#end of if
        else{
            
            Write-Host "Exit selected, or Invalid choice number. End of Script " -ForegroundColor Red -BackgroundColor White
            
            Exit;
        }#end of else

}#end of else method to connect

foreach ($vCServer in $vCServerList){
            
    #Connect to Vcenter
    $Script:vcInfo = Connect-VIServer -Server $WorkingServer -Port $port -WarningAction Continue -ErrorAction Stop -Credential $vCenterCred
     
    Write-Host "You are connected to vCenter: $WorkingServer" -ForegroundColor White -BackGroundColor DarkMagenta

}

}#End of Function Connect to Vcenter

############################################################################################################################
#function to remove snapshot

function Remove-SnapshotAuto
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [System.DateTime]$trimDate,

        # Param2 help description
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [ValidateSet('DNRTeste','DNR3','DNR4','DNR5','DNR6','DNR10')]
        [System.String]$doNotRemoveString = 'DNR3'


       )

if ($trimDate -eq $null){

    switch ($doNotRemoveString)
    {
    'DNR3' {
    
        [System.DateTime]$trimDate = (Get-Date).AddHours(-72)
    
    }
    'DNR4' {
    
        [System.DateTime]$trimDate = (Get-Date).AddHours(-96)
    
    }
    'DNR5' {
    
        [System.DateTime]$trimDate = (Get-Date).AddHours(-120)
    
    }
    'DNR6' {
    
        [System.DateTime]$trimDate = (Get-Date).AddHours(-144)
    
    }
    'DNR10' {
    
        [System.DateTime]$trimDate = (Get-Date).AddHours(-240)
    
    }
    'DNRTeste' {
    
        [System.DateTime]$trimDate = (Get-Date).AddMinutes(-10)
    
    }
    
}#end of Switch

}#end of IF
else{

    Write-Host "I will remove Snapshots older than: $trimDate" -ForegroundColor White -BackgroundColor Red

}#end of else


[System.String]$numberOfDays = $doNotRemoveString.Substring(3,1)

$snapshotList = VMware.VimAutomation.Core\Get-Vm -Server $WorkingServer | Get-Snapshot | Where-Object -FilterScript {$_.Created -le "$trimdate" -and $_.Description -notlike "*$doNotRemoveString*"}

    if(!($snapshotList)){
    
        Write-Output "In: $currentDate there are no snapshots to remove in vCenter $WorkingServer according to parameters: $numberOfDays days ago and $doNotRemoveString string in description field" | Out-File -FilePath $outputFile -Append

        Write-Host "In: $screenDate there are no snapshots to remove in vCenter: $WorkingServer according to parameters: $numberOfDays days ago and $doNotRemoveString string in description field" -ForegroundColor White -BackgroundColor DarkBlue

    }#end of IF
    else{
                
        Write-Output "Snapshots Deleted on: $fileDate" | Out-File -FilePath $outputFile -Append
    
        Write-Output "`n"

        foreach ($snap in $snapshotList){
    
            [System.String]$snapName = $snap.Name
     
            [System.String]$vmName = $snap.VM.Name

            $vMObj = $snap.vm

            [System.Boolean]$mountedTools = $vMObj.ExtensionData.Runtime.ToolsInstallerMounted
     
            #Validate if VM has VmTools mounted
            If ($mountedTools){
     
                Write-Output "VM: $vmName has Vmtools mounted in it's CD/DVD DRIVE. I will unmount it before remove Snapshot"

                $vMObj | Dismount-Tools -Verbose
        
                Start-Sleep -Seconds 10 -Verbose  
     
            }#End of IF
     
            Write-Output "Now I will remove Snapshot with Name: $snapName of the VM $vmName ..." 
       
            $snap | Select-Object -Property VM,VMId,PowerState,Name,Description,Created,SizeGB | Out-File -FilePath $outputFile -Append

            Get-VM -Name $vmName | 
            Get-Snapshot -Name $snapName |
            Remove-Snapshot -RunAsync -RemoveChildren -Confirm:$false -Verbose

        }#end forEach

        DisplayStart-Sleep -totalSeconds 30

        #LISTA DE VMs para verificar se é necessário consolidar discos.
        
        $vmList = @()
        
        $vmList = $snapshotList.VM.Name

        #IF NECESSARY CONSOLIDATE DISKS
        foreach ($tmpVM in $vmList){
    
            $vmObj = Get-VM -Name $tmpvm

            $consolidationNeeded = $vmObj.ExtensionData.Runtime.ConsolidationNeeded

            if ($consolidationNeeded -like 'False'){ 
        
                Write-Host "The VM $tmpVM does not need consolidation disk" -ForegroundColor White -BackgroundColor DarkGreen
                
                Write-Output "The VM $tmpVM does not need consolidation disk" | Out-File -FilePath $outputFile -Append 

            }#end of IF
            else{
                
                Write-Host "The VM $tmpVM needs consolidation disk" -ForegroundColor White -BackgroundColor DarkGreen
                
                Write-Output "The VM $tmpVM needs consolidation disk" | Out-File -FilePath $outputFile -Append

                $vmObj.ExtensionData.ConsolidateVMDisks()
                 
            }#end of Else
    
        }#end forEach

    }#end of Else

}#End of Function

############################################################################################################################
#MAIN SCRIPT

$folderName = 'Daily-Report-Snapshot'

#Define Date to Remove Snapshot

$currentDate = (Get-Date -Format "ddMMyyyy-HHmm").ToString()

$screenDate = Get-Date -Format "dddd MM/dd/yyyy HH:mm K"

$fileDate = (Get-date).ToString()

#$dateToDisregard = (Get-Date).AddHours(-144)

#USE FOR TEST
#$dateToDisregard = (Get-Date).AddMinutes(-1)

#[System.String]$DNRString = 'DNR6'

$vcNameList = @()

$vcNameList = ('server1','server2','server3.yourdomain.local') | Sort-Object

#USE FOR TEST
#$vcNameList = ('test-server','test-server2')

############################################################################################################################

$Script_Parent = Split-Path -Parent $MyInvocation.MyCommand.Definition

#Create Folder to Export Results
############################################################################################################################
$outputPathExists = Test-Path -Path "$Script_Parent\$folderName"

 if (!($outputPathExists)){

    Write-Host "Folder Named: $folderName does not exists. I will create it" -ForegroundColor Yellow -BackgroundColor Black

    New-Item -Path $Script_Parent -ItemType Directory -Name $folderName -Confirm:$false -Verbose -Force

}
else{

    Write-Host "Folder Named: $folderName already exists" -ForegroundColor White -BackgroundColor Blue
            
    Write-Output "`n"
 
}#END OF ELSE

#File Output
$Script:outputFile = ($Script_Parent + "\$($folderName)\RemoveSnapshots_HCPVMware_$($currentDate)_VC.txt") 


foreach ($vcName in $vcNameList)
{
    
    Connect-ToVcenterServer -methodToConnect Automatic -vCServerList $vcName -port 443 

    Remove-SnapshotAuto -doNotRemoveString DNR3

    Disconnect-ViServer -Server $script:WorkingServer -Force -Confirm:$false -ErrorAction SilentlyContinue
    
}#end of ForEach vCenter

Write-Host "End of Script" -ForegroundColor White -BackgroundColor Red