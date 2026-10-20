"""
sparkenv.py - makes `python my_script.py` just work for PySpark on Windows.

Put this as the FIRST import of any PySpark script in this folder:

    import sparkenv          # must come before `import pyspark`
    from pyspark.sql import SparkSession

What it does
  1. If the script was started with another Python (e.g. system 3.14),
     it re-launches the same script with pyspark_env's Python 3.11.
  2. Sets JAVA_HOME, HADOOP_HOME, PATH (winutils.exe + hadoop.dll),
     PYSPARK_PYTHON / PYSPARK_DRIVER_PYTHON for this process only.
     Nothing global on the machine is changed.
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
HADOOP_HOME = os.path.join(HERE, "hadoop")

_CANDIDATE_ENVS = [
    os.path.expandvars(r"%USERPROFILE%\.conda\envs\pyspark_env"),
    r"C:\ProgramData\anaconda3\envs\pyspark_env",
    os.path.expandvars(r"%USERPROFILE%\anaconda3\envs\pyspark_env"),
]
ENV_PREFIX = next((p for p in _CANDIDATE_ENVS
                   if os.path.exists(os.path.join(p, "python.exe"))), None)


def _same(a, b):
    return os.path.normcase(os.path.abspath(a)) == os.path.normcase(os.path.abspath(b))


def _relaunch_in_env():
    """Re-run the calling script with pyspark_env's python, then exit."""
    if not ENV_PREFIX or os.environ.get("SPARKENV_CHILD"):
        return
    env_py = os.path.join(ENV_PREFIX, "python.exe")
    script = sys.argv[0] if sys.argv else ""
    if _same(sys.executable, env_py) or not script.lower().endswith(".py"):
        return                                   # already in env / interactive
    print(f"[sparkenv] Python {sys.version.split()[0]} detected -> "
          f"re-running with pyspark_env ({env_py})", flush=True)
    child_env = dict(os.environ, SPARKENV_CHILD="1")
    rc = subprocess.call([env_py, os.path.abspath(script), *sys.argv[1:]],
                         env=child_env)
    sys.exit(rc)


def _configure():
    py = sys.executable
    os.environ["PYSPARK_PYTHON"] = py
    os.environ["PYSPARK_DRIVER_PYTHON"] = py
    os.environ.pop("SPARK_HOME", None)           # use pip-installed Spark

    path_add = []
    if os.path.isdir(HADOOP_HOME):
        os.environ["HADOOP_HOME"] = HADOOP_HOME  # overrides global C:\hadoop
        path_add.append(os.path.join(HADOOP_HOME, "bin"))

    if ENV_PREFIX and _same(py, os.path.join(ENV_PREFIX, "python.exe")):
        java_home = os.path.join(ENV_PREFIX, "Library")
        if os.path.exists(os.path.join(java_home, "bin", "java.exe")):
            os.environ["JAVA_HOME"] = java_home  # env's OpenJDK 17
            path_add.append(os.path.join(java_home, "bin"))
        path_add += [ENV_PREFIX, os.path.join(ENV_PREFIX, "Scripts")]

    # PATH is inherited by the JVM -> hadoop.dll is found (fixes
    # UnsatisfiedLinkError: NativeIO$Windows.access0)
    os.environ["PATH"] = os.pathsep.join(path_add + [os.environ.get("PATH", "")])


_relaunch_in_env()
_configure()
print(f"[sparkenv] Python {sys.version.split()[0]} | "
      f"JAVA_HOME={os.environ.get('JAVA_HOME')} | "
      f"HADOOP_HOME={os.environ.get('HADOOP_HOME')}", flush=True)
