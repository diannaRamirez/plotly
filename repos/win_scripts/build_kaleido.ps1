$Env:CC_VERSION="cc"

if ($env:cpus -eq $null -or $env:cpus -notmatch '^\d+$') {
    # Set the cpus environment variable to 4
    $env:cpus = 4
}

$ErrorActionPreference = "Stop"

$original_path = $env:path
$original_pwd = $pwd | Select -ExpandProperty Path
function CleanUp {
	$env:path = "$original_path"
	cd $original_pwd
}

trap { CleanUp }
function CheckLastExitCode {
    param ([int[]]$SuccessCodes = @(0), [scriptblock]$CleanupScript=$null)

    if ($SuccessCodes -notcontains $LastExitCode) {
        $msg = @"
EXE RETURNED EXIT CODE $LastExitCode
CALLSTACK:$(Get-PSCallStack | Out-String)
"@
        throw $msg
    }
}

$arch = $args[0]
$ninja = $false
if ($args[1] -eq "--from-ninja") {
	$ninja = $true
} elseif ($args[0] -eq "--from_ninja") {
	$ninja = $true
	$arch = $args[1]
}
echo $arch
if (-not ($arch -eq "x86" -or $arch -eq "x64")) {
    throw "Invalid architecture,: must be one of x86 or x64: received $arch"
}


# save current directory

# cd to repos directory
cd $PSScriptRoot\..

# Add depot_tools to path
$env:path = "$pwd\depot_tools;$pwd\depot_tools\bootstrap;$env:path"
echo $env:path

# Tell gclient not to update depot_tools
$env:DEPOT_TOOLS_UPDATE=0
# Tell gclient to use local Vistual Studio install
$env:DEPOT_TOOLS_WIN_TOOLCHAIN=0


$env:GCLIENT_PY3=0

# Write Versions
if (-not $ninja) {

	# Update version based on git tag
	python3 .\version\build_pep440_version.py
	CheckLastExitCode

	# Copy README and LICENSE to kaleido (For consistency with Linux docker build process)
	cp ..\README.md .\kaleido\
	cp ..\LICENSE.txt .\kaleido\
	cp .\CREDITS.html .\kaleido\

	# Check python version
	python3 --version
	CheckLastExitCode
	python3 -c "import sys; print(sys.prefix)"
	CheckLastExitCode
}
# cd to repos/src
cd src

# Prep for Ninja
if (-not $ninja) {
	# Make output directory
	if (-Not (Test-Path out\Kaleido_win_$arch)) {
	    New-Item -Path out\Kaleido_win_$arch -ItemType "directory" -ErrorAction Ignore
	}

	# Write out/Kaleido_win/args.gn
	Copy-Item ..\win_scripts\args_$arch.gn -Destination out\Kaleido_win_$arch\args.gn


	# Perform build, result will be out/Kaleido_win/kaleido
	gn gen out\Kaleido_win_$arch
	CheckLastExitCode
}

# Copy kaleido/kaleido.cc to src/headless/app/kaleido.cc
if (Test-Path headless\app\scopes) {
    Remove-Item -Recurse -Force headless\app\scopes
}

Copy-Item ..\kaleido\${env:CC_VERSION}\* -Destination headless\app\ -Recurse # we do this twice to make sure it has ur changes after gn ge
ninja -C out\Kaleido_win_$arch -j $env:cpus kaleido
CheckLastExitCode

# Copy build files
if (-Not (Test-Path ..\build\kaleido)) {
    New-Item -Path ..\build\kaleido -ItemType "directory"
}
Remove-Item -Recurse -Force ..\build\kaleido\* -ErrorAction Ignore
New-Item -Path ..\build\kaleido\bin -ItemType "directory"

Copy-Item out\Kaleido_win_$arch\kaleido.exe -Destination ..\build\kaleido\bin -Recurse

Copy-Item out\Kaleido_win_$arch\swiftshader -Destination ..\build\kaleido\bin -Recurse

# version
cp ..\kaleido\version ..\build\kaleido\

# license
cp ..\kaleido\LICENSE.txt ..\build\kaleido\
cp ..\kaleido\CREDITS.html ..\build\kaleido\

# mathjax
if (-Not (Test-Path ..\build\kaleido\etc)) {
    New-Item -Path ..\build\kaleido\etc -ItemType "directory"
}
Expand-Archive -LiteralPath '..\vendor\Mathjax-2.7.5.zip' -DestinationPath ..\build\kaleido\etc\
Rename-Item -Path ..\build\kaleido\etc\Mathjax-2.7.5 -NewName mathjax

# Copy icudtl.dat
Copy-Item .\out\Kaleido_win_$arch\icudtl.dat -Destination ..\build\kaleido\bin

# Copy javascript
cd ..\kaleido\js\
if (-Not (Test-Path build)) {
    New-Item -Path build -ItemType "directory"
}
npm install
CheckLastExitCode
npm run clean
CheckLastExitCode
npm run build
CheckLastExitCode

# Back to src
cd ..\..\src
if (-Not (Test-Path ..\build\kaleido\js\)) {
    New-Item -Path ..\build\kaleido\js\ -ItemType "directory"
}
Copy-Item ..\kaleido\js\build\*.js -Destination ..\build\kaleido\js\ -Recurse

# Copy kaleido.cmd launch script
Copy-Item ..\win_scripts\kaleido.cmd -Destination ..\build\kaleido\

# Build python wheel
$env:path = $original_path
cd ..\kaleido\py
$env:KALEIDO_ARCH=$arch
python3 setup.py package
CheckLastExitCode

# Change up to kaleido/ directory
cd ..

# Build kaleido zip archive
if (Test-Path ..\build\kaleido_win.zip) {
    Remove-Item -Recurse -Force ..\build\kaleido_win.zip
}
Compress-Archive -Force -Path ..\build\kaleido -DestinationPath ..\build\kaleido_win_$arch.zip

# Build wheel zip archive
if (Test-Path ..\kaleido\py\kaleido_wheel.zip) {
    Remove-Item -Recurse -Force ..\kaleido\py\kaleido_wheel.zip
}
Compress-Archive -Force -Path ..\kaleido\py\dist -DestinationPath ..\kaleido\py\kaleido_wheel.zip

cd ..\..

CleanUp
