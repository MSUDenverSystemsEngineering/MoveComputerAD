﻿<#
.SYNOPSIS
	This script performs the installation or uninstallation of an application(s).
.DESCRIPTION
	The script is provided as a template to perform an install or uninstall of an application(s).
	The script either performs an "Install" deployment type or an "Uninstall" deployment type.
	The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
	The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
	The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
	Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
	Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
	Disables logging to file for the script. Default is: $false.
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
.EXAMPLE
    Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"
.NOTES
	Toolkit Exit Code Ranges:
	60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
	69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
	70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	[ValidateSet('Install','Uninstall')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory=$false)]
	[ValidateSet('Interactive','Silent','NonInteractive')]
	[string]$DeployMode = 'Interactive',
	[Parameter(Mandatory=$false)]
	[switch]$AllowRebootPassThru = $false,
	[Parameter(Mandatory=$false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory=$false)]
	[switch]$DisableLogging = $false
)

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch { Write-Error -Message "Unable to set the PowerShell Execution Policy to Bypass for this process." }

	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	## Variables: Application
	[string]$appVendor = ''
	[string]$appName = ''
	[string]$appVersion = ''
	[string]$appArch = ''
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '1.0.0'
	[string]$appScriptDate = '02/12/2017'
	[string]$appScriptAuthor = '<author name>'
	##*===============================================
	## Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = ''
	[string]$installTitle = ''

	##* Do not modify section below
	#region DoNotModify

	## Variables: Exit Code
	[int32]$mainExitCode = 0

	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.6.9'
	[string]$deployAppScriptDate = '02/12/2017'
	[hashtable]$deployAppScriptParameters = $psBoundParameters

	## Variables: Environment
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	}
	Catch {
		If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}

	#endregion
	##* Do not modify section above
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================

	If ($deploymentType -ine 'Uninstall') {
		##*===============================================
		##* PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'

		## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
		Show-InstallationWelcome -CloseApps 'iexplore' -AllowDefer -DeferTimes 3 -CheckDiskSpace -PersistPrompt

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Installation tasks here>

		$msil = Get-ChildItem $dirFiles\32-Bit | Where-Object { $_.Attributes -eq 'Directory' } | Where-Object { $_.FullName -like "*msil_microsoft-windows-d..ivecenter.resources*" }
		$madm = Get-ChildItem $dirFiles\32-Bit | Where-Object { $_.Attributes -eq 'Directory' } | Where-Object { $_.FullName -like "*x86_microsoft.activedirectory.management*" }
		$madm64 = Get-ChildItem $dirFiles\64-Bit | Where-Object { $_.Attributes -eq 'Directory' } | Where-Object { $_.FullName -like "*amd64_microsoft.activedir..anagement.resources*" }

		If (-not (Test-Path $envWinDir\System32\WindowsPowerShell\v1.0\Modules\ActiveDirectory)) {
			Copy-File -Path "$dirFiles\32-Bit\ActiveDirectory" -Destination "$envWinDir\System32\WindowsPowerShell\v1.0\Modules" -Recurse
		}

		If (-not (Test-Path $envWinDir\Microsoft.NET\assembly\GAC_32\Microsoft.ActiveDirectory.Management)) {
			Copy-File -Path "$dirFiles\32-Bit\Microsoft.ActiveDirectory.Management" -Destination "$envWinDir\Microsoft.NET\assembly\GAC_32" -Recurse
		}

		If (-not (Test-Path $envWinDir\Microsoft.NET\assembly\GAC_32\Microsoft.ActiveDirectory.Management.Resources)) {
			Copy-File -Path "$dirFiles\32-Bit\Microsoft.ActiveDirectory.Management.Resources" -Destination "$envWinDir\Microsoft.NET\assembly\GAC_32" -Recurse
		}

		If (-not (Test-Path $envWinDir\WinSxS\$msil)) {
			Copy-File -Path "$dirFiles\32-Bit\$msil" -Destination "$envWinDir\WinSxS" -Recurse
		}

		If (-not (Test-Path $envWinDir\WinSxS\$madm)) {
			Copy-File -Path "$dirFiles\32-Bit\$madm" -Destination "$envWinDir\WinSxS" -Recurse
		}


		If ($envOSArchitecture -eq "64-Bit") {

			If (-not (Test-Path $envWinDir\SysWOW64\WindowsPowerShell\v1.0\Modules\ActiveDirectory)) {
				Copy-File -Path "$dirFiles\64-Bit\ActiveDirectory" -Destination "$envWinDir\SysWOW64\WindowsPowerShell\v1.0\Modules" -Recurse
			}

			If (-not (Test-Path $envWinDir\Microsoft.NET\assembly\GAC_64\Microsoft.ActiveDirectory.Management)) {
				Copy-File -Path "$dirFiles\64-Bit\Microsoft.ActiveDirectory.Management" -Destination "$envWinDir\Microsoft.NET\assembly\GAC_64" -Recurse
			}

			If (-not (Test-Path $envWinDir\Microsoft.NET\assembly\GAC_64\Microsoft.ActiveDirectory.Management.Resources)) {
				Copy-File -Path "$dirFiles\64-Bit\Microsoft.ActiveDirectory.Management.Resources" -Destination "$envWinDir\Microsoft.NET\assembly\GAC_64" -Recurse
			}

			If (-not (Test-Path $envWinDir\WinSxS\$madm64)) {
				Copy-File -Path "$dirFiles\64-Bit\$madm64" -Destination "$envWinDir\WinSxS" -Recurse
			}

		}


		##*===============================================
		##* INSTALLATION
		##*===============================================
		[string]$installPhase = 'Installation'

		## Handle Zero-Config MSI Installations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) { $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ } }
		}

		## <Perform Installation tasks here>

		#Test AD Module functionality
		Import-Module ActiveDirectory
		Get-ADComputer "ms15cs"

		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'

		## <Perform Post-Installation tasks here>

		## Display a message at the end of the install
		If (-not $useDefaultMsi) { Show-InstallationPrompt -Message 'You can customize text to appear at the end of an install or remove it completely for unattended installations.' -ButtonRightText 'OK' -Icon Information -NoWait }
	}
	ElseIf ($deploymentType -ieq 'Uninstall')
	{
		##*===============================================
		##* PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'

		## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
		Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Uninstallation tasks here>


		##*===============================================
		##* UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Uninstallation'

		## Handle Zero-Config MSI Uninstallations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}

		# <Perform Uninstallation tasks here>

		If (Test-Path $envWinDir\System32\WindowsPowerShell\v1.0\Modules\ActiveDirectory) {
			Remove-Folder -Path "$envWinDir\System32\WindowsPowerShell\v1.0\Modules\ActiveDirectory"
		}

		If (Test-Path $envWinDir\Microsoft.NET\assembly\GAC_32\Microsoft.ActiveDirectory.Management) {
			Remove-Folder -Path "$envWinDir\Microsoft.NET\assembly\GAC_32\Microsoft.ActiveDirectory.Management"
		}

		If (Test-Path $envWinDir\Microsoft.NET\assembly\GAC_32\Microsoft.ActiveDirectory.Management.Resources) {
			Remove-Folder -Path "$envWinDir\Microsoft.NET\assembly\GAC_32\Microsoft.ActiveDirectory.Management.Resources"
		}

		If (Test-Path $envWinDir\WinSxS\$msil) {
			Remove-Folder -Path "$envWinDir\WinSxS\$msil"
		}

		If (Test-Path $envWinDir\WinSxS\$madm) {
			Remove-Folder -Path "$envWinDir\WinSxS\$madm"
		}


		If ($envOSArchitecture -eq "64-Bit") {

			If (Test-Path $envWinDir\SysWOW64\WindowsPowerShell\v1.0\Modules\ActiveDirectory) {
				Remove-Folder -Path "$envWinDir\SysWOW64\WindowsPowerShell\v1.0\Modules\ActiveDirectory"
			}

			If (Test-Path $envWinDir\Microsoft.NET\assembly\GAC_64\Microsoft.ActiveDirectory.Management) {
				Remove-Folder -Path "$envWinDir\Microsoft.NET\assembly\GAC_64\Microsoft.ActiveDirectory.Management"
			}

			If (Test-Path $envWinDir\Microsoft.NET\assembly\GAC_64\Microsoft.ActiveDirectory.Management.Resources) {
				Remove-Folder -Path "$envWinDir\Microsoft.NET\assembly\GAC_64\Microsoft.ActiveDirectory.Management.Resources"
			}

			If (Test-Path $envWinDir\WinSxS\$madm64) {
				Remove-Folder -Path "$envWinDir\WinSxS\$madm64"
			}

		}
		##*===============================================
		##* POST-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Uninstallation'

		## <Perform Post-Uninstallation tasks here>


	}

	##*===============================================
	##* END SCRIPT BODY
	##*===============================================

	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode
}
