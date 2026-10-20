HOW TO RUN PYSPARK CODE ON THIS MACHINE
=======================================
Environment : C:\Users\karth\.conda\envs\pyspark_env
              Python 3.11  |  OpenJDK 17 (Zulu)  |  PySpark 3.5.x
Hadoop      : C:\Users\karth\Documents\PySpark-Lab\hadoop\bin (winutils.exe, hadoop.dll)

Plain "python" in a new window = system Python 3.14 (has PySpark 4.2 in
AppData\Roaming) -> NOT the env. Always use one of the options below.

OPTION 1 - launcher (easiest, any cmd / PowerShell window)
----------------------------------------------------------
  cd %USERPROFILE%\Documents\PySpark-Lab
  run_pyspark.bat parquet_demo.py
  run_pyspark.bat my_other_script.py

OPTION 2 - activate the env in Command Prompt (cmd.exe)
-------------------------------------------------------
  C:\ProgramData\anaconda3\Scripts\activate.bat pyspark_env
  set HADOOP_HOME=%USERPROFILE%\Documents\PySpark-Lab\hadoop
  set JAVA_HOME=%CONDA_PREFIX%\Library
  python parquet_demo.py

OPTION 3 - Anaconda Prompt / Anaconda PowerShell Prompt (Start menu)
--------------------------------------------------------------------
  conda activate pyspark_env
  cd %USERPROFILE%\Documents\PySpark-Lab
  python parquet_demo.py

CHECK YOU ARE IN THE RIGHT PYTHON
---------------------------------
  where python        -> first line must be ...\envs\pyspark_env\python.exe
  python -c "import pyspark,sys; print(sys.version, pyspark.__version__)"
                      -> 3.11.x  3.5.x

VS CODE / JUPYTER
-----------------
  VS Code : Ctrl+Shift+P -> "Python: Select Interpreter" -> pyspark_env
  Jupyter : run_pyspark.bat -m pip install ipykernel
            run_pyspark.bat -m ipykernel install --user --name pyspark_env --display-name "PySpark (3.11)"
