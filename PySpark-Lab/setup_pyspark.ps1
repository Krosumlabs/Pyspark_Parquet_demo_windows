# =====================================================================
#  PySpark setup for Windows  -  isolated conda environment
#  Python 3.11  +  OpenJDK 17  +  PySpark 3.5.x  +  winutils/hadoop.dll
#
#  Run from this folder:
#     powershell -ExecutionPolicy Bypass -File .\setup_pyspark.ps1
#
#  Nothing global is changed: your existing Python / Java / conda base
#  stay untouched. All variables are scoped to the "pyspark_env" env.
# =====================================================================

$ErrorActionPreference = "Continue"
$Root      = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvName   = "pyspark_env"
$PyVer     = "3.11"
$JdkVer    = "17"
$PySpark   = "pyspark>=3.5.3,<3.6"
$HadoopTag = "hadoop-3.3.6"
$Log       = Join-Path $Root "setup_log.txt"

Start-Transcript -Path $Log -Force | Out-Null

function Step($msg) { Write-Host ""; Write-Host "==== $msg ====" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; Stop-Transcript | Out-Null; exit 1 }

# ---------------------------------------------------------------------
Step "1. Checking what is already installed"
# ---------------------------------------------------------------------
$sysPy = "not found"; $sysJava = "not found"
if (Get-Command python -ErrorAction SilentlyContinue) { $sysPy = (& python --version 2>&1 | Out-String).Trim() }
if (Get-Command java   -ErrorAction SilentlyContinue) { $sysJava = (& java -version 2>&1 | Select-Object -First 1 | Out-String).Trim() }
Write-Host "System Python : $sysPy"
Write-Host "System Java   : $sysJava"
Write-Host "JAVA_HOME     : $env:JAVA_HOME"
Write-Host "HADOOP_HOME   : $env:HADOOP_HOME"
Write-Host "SPARK_HOME    : $env:SPARK_HOME"
Write-Host ""
Write-Host "PySpark 3.5 needs Python 3.8-3.11 and Java 8/11/17."
Write-Host "To avoid clashing with whatever versions are above, an isolated env is created."

if ($env:SPARK_HOME) {
    Write-Host "NOTE: SPARK_HOME is set globally. It is cleared by run_pyspark.bat so pip's PySpark is used." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------
Step "2. Locating conda (Anaconda / Miniconda)"
# ---------------------------------------------------------------------
$candidates = @(
    "$env:USERPROFILE\anaconda3\Scripts\conda.exe",
    "$env:USERPROFILE\miniconda3\Scripts\conda.exe",
    "$env:LOCALAPPDATA\anaconda3\Scripts\conda.exe",
    "$env:LOCALAPPDATA\miniconda3\Scripts\conda.exe",
    "$env:ProgramData\anaconda3\Scripts\conda.exe",
    "$env:ProgramData\Anaconda3\Scripts\conda.exe",
    "$env:ProgramData\miniconda3\Scripts\conda.exe",
    "C:\anaconda3\Scripts\conda.exe"
)
$cmd = Get-Command conda.exe -ErrorAction SilentlyContinue
if ($cmd) { $candidates = @($cmd.Source) + $candidates }
$Conda = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $Conda) { Fail "conda.exe not found. Install Miniconda (https://docs.conda.io/en/latest/miniconda.html) and re-run." }
Write-Host "conda: $Conda"
& $Conda --version

# ---------------------------------------------------------------------
Step "3. Creating env '$EnvName' (Python $PyVer + OpenJDK $JdkVer from conda-forge)"
# ---------------------------------------------------------------------
$envJson = (& $Conda env list --json) | Out-String | ConvertFrom-Json
$Prefix  = $envJson.envs | Where-Object { (Split-Path $_ -Leaf) -eq $EnvName } | Select-Object -First 1

if ($Prefix) {
    Write-Host "Env already exists at $Prefix - reusing it."
} else {
    & $Conda create -y -n $EnvName -c conda-forge --override-channels "python=$PyVer" "openjdk=$JdkVer"
    if ($LASTEXITCODE -ne 0) { Fail "conda create failed (see messages above)." }
    $envJson = (& $Conda env list --json) | Out-String | ConvertFrom-Json
    $Prefix  = $envJson.envs | Where-Object { (Split-Path $_ -Leaf) -eq $EnvName } | Select-Object -First 1
}
if (-not $Prefix) { Fail "Could not find env prefix for $EnvName." }

$EnvPython = Join-Path $Prefix "python.exe"
& $EnvPython --version

# Make sure Java is in the env (in case env pre-existed without it)
$JavaExe = Join-Path $Prefix "Library\bin\java.exe"
if (-not (Test-Path $JavaExe)) {
    Write-Host "Java not found in env - installing openjdk=$JdkVer ..."
    & $Conda install -y -n $EnvName -c conda-forge --override-channels "openjdk=$JdkVer"
}
if (-not (Test-Path $JavaExe)) {
    $found = Get-ChildItem -Path $Prefix -Recurse -Filter java.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $JavaExe = $found.FullName } else { Fail "java.exe not found inside env." }
}
$JavaHome = Split-Path (Split-Path $JavaExe -Parent) -Parent
& $JavaExe -version

# ---------------------------------------------------------------------
Step "4. Installing PySpark + helpers with pip (inside the env)"
# ---------------------------------------------------------------------
& $EnvPython -m pip install --upgrade pip
& $EnvPython -m pip install "$PySpark" "pyarrow" "pandas<2.3" "numpy<2"
if ($LASTEXITCODE -ne 0) { Fail "pip install failed." }

# ---------------------------------------------------------------------
Step "5. Windows Hadoop helpers (winutils.exe + hadoop.dll)"
# ---------------------------------------------------------------------
$HadoopHome = Join-Path $Root "hadoop"
$HadoopBin  = Join-Path $HadoopHome "bin"
New-Item -ItemType Directory -Force -Path $HadoopBin | Out-Null
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
foreach ($f in @("winutils.exe", "hadoop.dll")) {
    $dest = Join-Path $HadoopBin $f
    if (Test-Path $dest) { Write-Host "$f already present"; continue }
    $url = "https://github.com/cdarlint/winutils/raw/master/$HadoopTag/bin/$f"
    Write-Host "Downloading $url"
    try { Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing }
    catch { Fail "Download of $f failed: $($_.Exception.Message)" }
}
# hadoop.dll must be on PATH; env's Library\bin is on PATH whenever the env is active
Copy-Item (Join-Path $HadoopBin "hadoop.dll") (Join-Path $Prefix "Library\bin\hadoop.dll") -Force
Get-ChildItem $HadoopBin | Format-Table Name, Length

# ---------------------------------------------------------------------
Step "6. Setting environment variables (scoped to '$EnvName')"
# ---------------------------------------------------------------------
& $Conda env config vars set -n $EnvName `
    "JAVA_HOME=$JavaHome" `
    "HADOOP_HOME=$HadoopHome" `
    "PYSPARK_PYTHON=$EnvPython" `
    "PYSPARK_DRIVER_PYTHON=$EnvPython"
& $Conda env config vars list -n $EnvName

# Launcher that works even without "conda activate"
$bat = @"
@echo off
REM Runs any PySpark script with the pyspark_env settings.
REM Usage:  run_pyspark.bat parquet_demo.py
set "JAVA_HOME=$JavaHome"
set "HADOOP_HOME=$HadoopHome"
set "PYSPARK_PYTHON=$EnvPython"
set "PYSPARK_DRIVER_PYTHON=$EnvPython"
set "SPARK_HOME="
set "PATH=$JavaHome\bin;$HadoopBin;$Prefix;$Prefix\Library\bin;$Prefix\Scripts;%PATH%"
"$EnvPython" %*
"@
Set-Content -Path (Join-Path $Root "run_pyspark.bat") -Value $bat -Encoding ASCII
Write-Host "Created run_pyspark.bat"

# ---------------------------------------------------------------------
Step "7. Smoke test"
# ---------------------------------------------------------------------
$test = Join-Path $Root "_smoke_test.py"
@"
from pyspark.sql import SparkSession
import pyspark, sys
spark = SparkSession.builder.master('local[*]').appName('smoke').getOrCreate()
spark.sparkContext.setLogLevel('ERROR')
print('Python  :', sys.version.split()[0])
print('PySpark :', pyspark.__version__)
print('Spark   :', spark.version)
print('Java    :', spark.sparkContext._jvm.java.lang.System.getProperty('java.version'))
print('Rows    :', spark.range(1000).count())
spark.stop()
print('SMOKE TEST OK')
"@ | Set-Content -Path $test -Encoding ASCII
& (Join-Path $Root "run_pyspark.bat") $test
Remove-Item $test -ErrorAction SilentlyContinue

Step "DONE"
Write-Host "Next:  .\run_pyspark.bat parquet_demo.py"
Write-Host "  or:  conda activate $EnvName ; python parquet_demo.py"
Stop-Transcript | Out-Null
