$PSDefaultParameterValues = @{ '*:Encoding' = 'utf8' }
write-host "***************************************************************"
write-host "**************** Setup script for opensim *********************"
write-host "********************* Welcome! ********************************"
write-host "First step: Setting up ssh for gitlab.uni-koblenz.de***********"
write-host "Warning: After executing the script it looks like the environment variables are not working. After a restart of the Powershell the environment variables work as desired! The functionality in the script is still guaranteed by the method refreshEnv." -ForegroundColor Yellow

$global:setupssh = $null
$global:initials = $null

function runAsAdmin() {
	$principal = new-object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
	$result = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
	if ($result -eq $true) {
		write-host "Script is running as admin - OK" -ForegroundColor Green
	} else {
		write-host "Please relaunch with admin privileges" -ForegroundColor Red
		write-host "Launching script as Admin" -ForegroundColor Green
		Start-Sleep 5
		Start-Process $PSScriptRoot\execution_policy.cmd -Verb runAs
		exit
	}
}

function testSSH() {
	write-host "Testing your ssh-environment..."
	ssh -T -o NumberOfPasswordPrompts=0 git@gitlab.uni-koblenz.de
	if ($lastExitCode -eq 0) {
		write-host "******** SSH-Authentication successful! ***********" -ForegroundColor Green
	}
		elseif ($lastExitCode -eq 255){
			write-host "Authentication failed, please setup ssh"
			$retry = Read-Host 'If "authentication failed", press N, else press Y. [Y/N]'
			if($retry -like "Y*") {
				testSSH
				return
			}
			$global:setupssh = $true
		}
			else {
				echo $lastExitCode
				write-host "Unknown state."
			}
}

function configureSSH() {
	if ($global:setupssh -eq $true) {
		write-host "*********** Generating ssh-key for your system ************"
		if ((Test-Path "$HOME\.ssh") -eq $false) {
			$null = md $HOME\.ssh
		}
		if (Test-Path "$HOME\.ssh\id_rsa") {
			write-host "id_rsa already available. Just printing the public key.." -ForegroundColor Green
		}
		else {
			write-host "Generating id_rsa key.." -ForegroundColor Yellow
			ssh-keygen -f $HOME\.ssh\id_rsa -t rsa -N '""'
		}	
		write-host "Copy the following output into Gitlab -> Settings -> "
		write-host "SSH-Keys and add the key. **********************************"
		write-host ""
		type $HOME\.ssh\id_rsa.pub
		write-host ""
		$global:ssh = Read-Host 'Have you configured your public key in gitlab? [Y/N]'
		if ($global:ssh -like "Y*") {
			testSSH
		}
		else {
			write-host "Reconfiguring ssh..."
			configureSSH
		}
			
	} else {
			echo "SSH is already configured, skipping..."
	}
 }

function createWorkingDir() {
	# create directory with nested folders and ignore errors when creating them
	$null = md C:\opensim\$global:initials -ea 0
	$null = md C:\opensim\installers -ea 0
}

function testWorkingDir() {
	write-host ""
	write-host "************** Creating a working directory. ******************"
	$global:initials = Read-Host 'Please enter you initials (Example Max Mustermann = MM)'
	$global:initials = $global:initials.toUpper()
	if (Test-Path "C:\opensim\$global:initials") {
		write-host "Verified the working directory!" -ForegroundColor Green
		return $true
	}
	else {
		write-host "Creating the working directory now..."
		return $false
	}
}

function addOpensimToPath() {
	if ($env:Path -notmatch "OPENSIM") {
		write-host "Extending System Path with %OPENSIM%" -ForegroundColor Green
		if ($env:Path -match '\;$') {
			#[Environment]::SetEnvironmentVariable("Path", $env:Path + "%OPENSIM%" + ";", "Machine") --> DOES NOT WORK, %OPENSIM% does not get resolved
			setx /M PATH "$($env:path)%OPENSIM%;"
		}
		if ($env:Path -notmatch '\;$') {
			#[Environment]::SetEnvironmentVariable("Path", $env:Path + ";" + "%OPENSIM%" + ";", "Machine") --> DOES NOT WORK, %OPENSIM% does not get resolved
			setx /M PATH "$($env:path);%OPENSIM%;"
		}
		refreshEnv
		if ($env:Path -match "OPENSIM") {
			write-host "Successfully extended path with %OPENSIM%" -ForegroundColor Green
		}
	}
}

function createOpensimPath() {
	write-host "Creating OPENSIM system variable" -ForegroundColor Green
	[Environment]::SetEnvironmentVariable("OPENSIM", "dummy", "Machine")
	write-host "Successfully created OPENSIM system variable" -ForegroundColor Green
}

function createPythonPath() {
	write-host "Creating PYTHON_PATH, PYTHON_LIB, PYTHONHOME system variables" -ForegroundColor Green
	[Environment]::SetEnvironmentVariable("PYTHON_PATH", "C:\Python37", "Machine")
	[Environment]::SetEnvironmentVariable("PYTHON_LIB", "C:\Python37\libs", "Machine")
	[Environment]::SetEnvironmentVariable("PYTHONHOME", "C:\Python37", "Machine")
	refreshEnv
	write-host "Successfully created PYTHON_PATH, PYTHON_LIB, PYTHONHOME system variable" -ForegroundColor Green
}

function modifyOpensimPath([string] $path) {
	write-host "Modifying OPENSIM path variable, adding" $path -ForegroundColor Green
	$env:OPENSIM = [System.Environment]::GetEnvironmentVariable("OPENSIM", "Machine")
	if ($env:OPENSIM -match '\;$') {
		[Environment]::SetEnvironmentVariable("OPENSIM", $env:OPENSIM + $path, "Machine")
	}
	if ($env:OPENSIM -notmatch '\;$') {
		[Environment]::SetEnvironmentVariable("OPENSIM", $env:OPENSIM + ";" + $path, "Machine")
	}
	refreshEnv
	# clean the dummy entry if needed
	if ($env:OPENSIM -match "dummy") {
	Write-Host "Cleaning the dummy entry in the OPENSIM variable" -ForegroundColor Green
		$env:OPENSIM = $env:OPENSIM -replace "dummy;", ""
		[Environment]::SetEnvironmentVariable("OPENSIM", $env:OPENSIM, "Machine")
		refreshEnv
	}
}

function refreshEnv() {
	write-host "****************** Refreshing all script environment! *******************"
	$env:OPENSIM = [System.Environment]::GetEnvironmentVariable("OPENSIM","Machine")
	$env:PYTHON_PATH = [System.Environment]::GetEnvironmentVariable("PYTHON_PATH","Machine")
	$env:PYTHON_LIB = [System.Environment]::GetEnvironmentVariable("PYTHON_LIB","Machine")
	$env:PYTHONHOME = [System.Environment]::GetEnvironmentVariable("PYTHONHOME","Machine")
	# Path has to be refreshed in the last step!
	$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
	write-host "Printing modified path..." -ForegroundColor Yellow
	write-host "Path:" -ForegroundColor Yellow
	write-host $env:Path -ForegroundColor DarkCyan
	write-host "OPENSIM:" -ForegroundColor Yellow
	write-host $env:OPENSIM -ForegroundColor DarkCyan
	if (($env:PYTHON_PATH -match "Python37") -And ($env:PYTHON_LIB -match "Python37") -And ($env:PYTHONHOME -match "Python37")) {
		write-host "PYTHON_PATH:" -ForegroundColor Yellow
		write-host $env:PYTHON_PATH -ForegroundColor DarkCyan
		write-host "PYTHON_LIB:" -ForegroundColor Yellow
		write-host $env:PYTHON_LIB -ForegroundColor DarkCyan
		write-host "PYTHONHOME:" -ForegroundColor Yellow
		write-host $env:PYTHONHOME -ForegroundColor DarkCyan
	}
}

function opensimCorePaths() {
	# only call with paranthesis if using "+"-Operator and using one argument
	modifyOpensimPath("C:\opensim\" + $global:initials + "\install-opensim-deps\simbody\bin")
	modifyOpensimPath("C:\opensim\" + $global:initials + "\install-opensim-deps\simbody\lib")
	modifyOpensimPath("C:\opensim\" + $global:initials + "\install-opensim-deps")
	modifyOpensimPath("C:\opensim\" + $global:initials)
	modifyOpensimPath("C:\opensim\" + $global:initials + "\install-opensim-core")
	modifyOpensimPath("C:\opensim\" + $global:initials + "\install-opensim-core\bin")
	modifyOpensimPath("C:\opensim\" + $global:initials + "\install-opensim-core\sdk\lib")
	<# activate this part if other install stuff is done
	modifyOpensimPath("C:\opensim\" + $global:initials + "\opensimQt\build-PythonQt-Desktop_Qt_5_12_7_MSVC2017_64bit-Release\lib")
	modifyOpensimPath("C:\Program Files(x86)\VTK\bin")
	#>
}

function curlSoftware ([string] $url, [string] $filename, [string] $name) {
	write-host "Downloading software " $name -ForegroundColor Yellow
	$dest = "C:\opensim\installers\" + $filename
	if (Test-Path $dest) {
		write-host "Software is already downloaded.. Skipping" -ForegroundColor Green
	}
	else {
		Invoke-WebRequest $url -OutFile $dest
		#alternative method
		#$wc = New-Object System.Net.WebClient
		#$wc.DownloadFile($url, $dest)
		if (Test-Path C:\opensim\installers\$filename) {
			write-host "Successfully downloaded " $name -ForegroundColor Green
		}
		else {
			write-host "Error while downloading " + $name -ForegroundColor
			write-host "Retrying"
			curlSoftware($url, $filename, $name)
			return
		}
	}

}

function installGit([string] $filename) {
	if (Test-Path "C:\Program Files\Git\cmd\git.exe") {
		write-host "Git is already installed" -ForegroundColor Green
		write-host "Verifying path.."
		$path = (Get-Command git.exe).Path
		if ($path -match "git") {
			write-host "Successfully verified path!"
		}
		else {
			write-host "Something with your path is wrong".
			refreshEnv
		}
	}
	else {
		write-host "Installing Git.."
		$process = "C:\opensim\installers\" + $filename
		Start-Process -Wait $process /VERYSILENT
		if (Test-Path "C:\Program Files\Git\cmd\git.exe") {
			write-host "Successfully intalled Git" -ForegroundColor Green
			refreshEnv
		}
		$path = (Get-Command git.exe).Path
		if ($path -match "git") {
			write-host "Successfully verified git path!" -ForegroundColor Green
			write-host "git.exe found at " $path
		}
		else {
			write-host "Something with your path is wrong".
			refreshEnv
		}
		
	}
}

function installQt([string] $filename) {
	if (Test-Path "C:\Qt\Qt5.12.9\5.12.9\msvc2017_64") {
		write-host "Qt is already installed" -ForegroundColor Green
	}
	else {
		write-host "Installing Qt 5.12.9"
		write-host "Please use the following settings in the installer:" -ForegroundColor Yellow
		write-host ""
		write-host "Wait for 'Next'-Button -> Next -> Enter your login or create account" -ForegroundColor DarkCyan
		write-host "-> Next -> Check 'I am an individual person not using Qt for any company'" -ForegroundColor DarkCyan
		write-host "-> Check 'I have read and approve the obligations of using Open Source Qt'" -ForegroundColor DarkCyan
		write-host "-> Next -> Next -> Default 'C:\Qt\Qt5.12.9 and check 'Associate common file types with Qt Creator''" -ForegroundColor DarkCyan
		write-host "-> Next -> Expand 'Qt 5.12.9' and only select 'MSVC 2017 64-bit' -> Next " -ForegroundColor DarkCyan
		write-host "Check 'I have read and agree to the terms contained in the license agreements.' -> Next" -ForegroundColor DarkCyan
		write-host "-> Default '5.12.9' -> Next -> Install -> Next -> Uncheck 'Launch Qt Creator' -> Finish" -ForegroundColor DarkCyan
		write-host ""
		$process = "C:\opensim\installers\" + $filename
		Start-Process -Wait $process
		if (Test-Path "C:\Qt\Qt5.12.9\5.12.9\msvc2017_64") {
			write-host "Successfully intalled Qt" -ForegroundColor Green
			refreshEnv
		}
		else {
			write-host "Retry installing Qt, Qt not found" -ForegroundColor Red
			installQt($filename)
			return
		}		
	}
}

function installVS([string] $filename) {
	write-host "Installing c++ environment from Visual-Studio"
	if (Test-Path "C:\Program Files (x86)\Microsoft Visual Studio\2017" ) {
		write-host "Visual Studio already installed, skipping.." -ForegroundColor Green
	}
	else {
		write-host "Installing Visual Studio 2017 Community Edition" -ForegroundColor Yellow
		if (Test-Path "C:\opensim\installers\$filename") {
			write-host "Verified existence of '$filename' from git repository." -ForegroundColor Green
			$process = "C:\opensim\installers\" + $filename
			$layoutpath = "C:\opensim\installers\vslayout"
			write-host "Starting the installation of Visual Studio" -ForegroundColor Yellow
			Start-Process -Wait "$process" -ArgumentList "--layout $layoutpath --add Microsoft.VisualStudio.Workload.NativeDesktop --includeRecommended --lang en-US"
			if (Test-Path "C:\opensim\installers\vslayout\$filename") {
				write-host "Verified existence of Layout from Visual Studio" -ForegroundColor Green
				write-host "Starting installation" -ForegroundColor Yellow
				$process_inst = $layoutpath + "\" + $filename
				#write-host "Test" $process_inst
				Start-Process -Wait $process_inst -ArgumentList "--noweb --add Microsoft.VisualStudio.Workload.NativeDesktop --includeRecommended --passive"
				if (Test-Path "C:\Program Files (x86)\Microsoft Visual Studio\2017\Community") {
					write-host "Successfully installed Visual Studio Community Edition 2017" -ForegroundColor Green
					refreshEnv
				} else {
					write-host "Something went wrong when installing Visual Studio" -ForegroundColor Red
				}
			}
			else {
				write-host "Something went wrong when installing your Layout" -ForegroundColor Red
				$ retry = Read-Host "Do you want to retry? [Y/N]"
				if ($retry -Like "Y*") {
					installVS
				}
				return
			}
		}
		else {
			write-host "'vs_community.exe' is not present" -ForegroundColor Red
			write-host "Please verify your git repository" -ForegroundColor Red
		}
	}
}

function installPython([string] $filename) {
	write-host "Installaling python environment" -ForegroundColor yellow
	if (Test-Path "C:\Python37") {
		write-host "Python is already installed, just creating Path variables.." -ForegroundColor Green
		createPythonPath
	} else {
		if (Test-Path "C:\opensim\installers\$filename") {
			$process = "C:\opensim\installers\" + $filename
			write-host "Installing python.." -ForegroundColor Yellow
			Start-Process -Wait $process -ArgumentList "/quiet InstallAllUsers=1 PrependPath=0 TargetDir=C:\Python37"
			if (Test-Path "C:\Python37") {
				write-host "Successfully installed python" -ForegroundColor Green
				write-host "Setting the path variables needed for building.."
				createPythonPath
			} else {
				write-host "Something went wront when installing python" -ForegroundColor Red
			}
		} else {
			write-host "Something went wront when installing python" -ForegroundColor Red
			# implement Retry
		}
	}
}

function cloneAll() {
	if (Test-Path "C:\opensim\LM\buildEnv") {
		write-host "Sync already done, skipping.." -ForegroundColor Green
	}
	else {
		write-host "Cloning all needed source repositorys" -ForegroundColor Yellow
		# this line clones all source repos with the final setup
		git clone --recurse-submodules -j 4 https://github.com/lukasmuell3r/opensim-dev.git C:\opensim\$global:initials
		<# hardcoded LM because it's the building branch with empty building directorys
		git clone -b LM --recursive git@gitlab.uni-koblenz.de:IAKo/opensimdevgroup/opensim-dev.git C:\opensim\$global:initials
		cd C:\opensim\$global:initials
		#git checkout -b LM
		git clone git@gitlab.uni-koblenz.de:IAKo/opensimdevgroup/simbody.git C:\opensim\$global:initials\opensim-core\dependencies\simbody
		git clone git@gitlab.uni-koblenz.de:IAKo/opensimdevgroup/docopt.git  C:\opensim\$global:initials\opensim-core\dependencies\docopt
		git clone git@gitlab.uni-koblenz.de:IAKo/opensimdevgroup/BTK.git  C:\opensim\$global:initials\opensim-core\dependencies\BTK
		git clone git@gitlab.uni-koblenz.de:IAKo/opensimdevgroup/opensim-models.git C:\opensim\$global:initials\opensim-gui\opensim-models
		git clone git@gitlab.uni-koblenz.de:IAKo/opensimdevgroup/opensim-visualizer.git  C:\opensim\$global:initials\opensim-gui\opensim-visualizer
		git clone git@gitlab.uni-koblenz.de:IAKo/opensimdevgroup/three.js.git C:\opensim\$global:initials\opensim-gui\Gui\opensim\threejs #>
		write-host "Cloning finished" -ForegroundColor Green
	}
	# Todo check wether clone worked
}

function getShortPytonVersionAndConfQt() {
	$version = python --version
	if (![string]::IsNullOrEmpty($version)) {
		$find1 = "Python "
		$find2 = "."
		$replace = ""
		$version = $version.Replace($find1, $replace)
		$version = $version.Replace($find2, $replace)
		$version = $version.SubString(0,2)
		write-host "Detected Python version " $version -ForegroundColor Green
		write-host "Modyfying python.prf from pythonQt building directory.." -ForegroundColor yellow
		$file = "C:\opensim\$global:initials\opensimQt\pythonQt\build\python.prf"
		$findstr = "win32:PYTHON_VERSION=27"
		$replacestr = "win32:PYTHON_VERSION=" + $version
		(Get-Content $file).Replace($findstr, $replacestr)| Set-Content $file
	}
	
	
	
}

# here is the normal program start. functions have to be written above

# start - privlege verfication
runAsAdmin
# end

# start - SSH configuration (not needed since we switch to github.com and the repositorys are public)
#testSSH
#if ($global:setupssh -eq $true) {configureSSH}
# end

# start - creating working directory
$workingDirExists = testWorkingDir
if ($workingDirExists -eq $false) {createWorkingDir}
# end

# start - initial Path Environment Stuff
createOpensimPath
opensimCorePaths
addOpensimToPath
# has to be done manually at this step
refreshEnv
# end

# start curl software
curlSoftware "https://github.com/git-for-windows/git/releases/download/v2.28.0.windows.1/Git-2.28.0-64-bit.exe" "Git-2.28.0-64-bit.exe" "Git"
curlSoftware "https://download.qt.io/official_releases/qt/5.12/5.12.9/qt-opensource-windows-x86-5.12.9.exe" "qt-opensource-windows-x86-5.12.9.exe" "Qt"
curlSoftware "https://www.python.org/ftp/python/3.7.9/python-3.7.9-amd64.exe" "python-3.7.9-amd64.exe" "Python"
curlSoftware "https://github.com/Kitware/CMake/releases/download/v3.18.4/cmake-3.18.4-win64-x64.msi" "cmake-3.18.4-win64-x64.msi" "Cmake"
curlSoftware "https://download.visualstudio.microsoft.com/download/pr/5f6dfbf7-a8f7-4f36-9b9e-928867c28c08/da9f4f32990642c17a4188493949adcfd785c4058d7440b9cfe3b291bbb17424/vs_Community.exe" "vs_Community.exe" "Visual Studio 2017 CE"
curlSoftware "http://doxygen.nl/files/doxygen-1.8.20-setup.exe" "doxygen-1.8.20-setup.exe" "Doxygen"
curlSoftware "https://de.osdn.net/frs/g_redir.php?m=jaist&f=swig%2Fswigwin%2Fswigwin-3.0.12%2Fswigwin-3.0.12.zip" "swigwin-3.0.12.zip"
curlSoftware "https://github.com/Kitware/VTK/archive/v9.0.1.zip" "VTK9.0.1.zip" "VTK 9.0.1"
# end

# start - install git
installGit "Git-2.28.0-64-bit.exe"
# end

# start - sync repos
cloneAll
# end

#TODO.txt lesen!! Hier geht es weiter mit dem Testen.
# start - install vs
installVS "vs_Community.exe"
# end

# start - install qt
installQT "qt-opensource-windows-x86-5.12.9.exe"
modifyOpensimPath "C:\Qt\Qt5.12.9\5.12.9\msvc2017_64\bin"
modifyOpensimPath "C:\Qt\Qt5.12.9\5.12.9\msvc2017_64\lib"
#next line to test path
#qtdiag.exe -version

# end

# start install python
installPython "python-3.7.9-amd64.exe"
modifyOpensimPath "C:\Python37"
# add the python paths to the scripts environment
# $vers = python --version
# if ($vers -match "3.7.9") {
#	write-host "Successfully installed python" -ForegroundColor Green
#}
# end


# start - configure qt prf file
getShortPytonVersionAndConfQt
# type "C:\opensim\$global:initials\opensimQt\pythonQt\build\python.prf"
# end

# start - work here 



# end

#################### Additional information #################
# start - To add additionals paths use the following two lines
<# this function refreshs the env automatically
modifyOpensimPath(path)
#>
# end -

# personal testscripts in the new paths here (will not run in your environment)
<# testpath
#>


# start - End of the script
# pause the script an wait for any key to finish
Write-Host "******************** End of Script *******************"
Read-Host -Prompt "Press any key and/or press enter to continue.."
# end











#powershell.exe -NoP -NonI -Command "Expand-Archive '${PSScriptRoot}\curl-7.72.0_5-win64-mingw.zip' 'C:\Program Files\curl-7'"