@echo off
REM Runs any PySpark script with the pyspark_env settings.
REM Usage:  run_pyspark.bat parquet_demo.py
set "JAVA_HOME=C:\Users\karth\.conda\envs\pyspark_env\Library"
set "HADOOP_HOME=C:\Users\karth\Documents\PySpark-Lab\hadoop"
set "PYSPARK_PYTHON=C:\Users\karth\.conda\envs\pyspark_env\python.exe"
set "PYSPARK_DRIVER_PYTHON=C:\Users\karth\.conda\envs\pyspark_env\python.exe"
set "SPARK_HOME="
set "PATH=C:\Users\karth\.conda\envs\pyspark_env\Library\bin;C:\Users\karth\Documents\PySpark-Lab\hadoop\bin;C:\Users\karth\.conda\envs\pyspark_env;C:\Users\karth\.conda\envs\pyspark_env\Library\bin;C:\Users\karth\.conda\envs\pyspark_env\Scripts;%PATH%"
"C:\Users\karth\.conda\envs\pyspark_env\python.exe" %*
