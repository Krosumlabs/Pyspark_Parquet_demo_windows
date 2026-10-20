"""
PySpark Parquet demo
--------------------
1. Build a DataFrame with an explicit schema
2. Transformations  (withColumn, filter, groupBy)   -> lazy
3. Actions          (show, count, collect, write)   -> trigger execution
4. Write Parquet, partitioned by region
5. Read the Parquet back: partition pruning, aggregation, Spark SQL

Run:   python parquet_demo.py      (sparkenv switches to pyspark_env automatically)
  or:  run_pyspark.bat parquet_demo.py
"""
import sparkenv  # noqa: F401  <- FIRST: picks pyspark_env + sets JAVA/HADOOP/PATH

import os
from datetime import date

from pyspark.sql import SparkSession, functions as F
from pyspark.sql.types import (StructType, StructField, StringType,
                               IntegerType, DoubleType, DateType)

BASE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(BASE, "output", "sales_parquet")

# ---------------------------------------------------------------- session
spark = (SparkSession.builder
         .appName("ParquetDemo")
         .master("local[*]")                          # all local CPU cores
         .config("spark.sql.shuffle.partitions", "4")  # small data -> few partitions
         .config("spark.driver.memory", "2g")
         .getOrCreate())
spark.sparkContext.setLogLevel("WARN")
print(f"\nSpark {spark.version} | UI: {spark.sparkContext.uiWebUrl}\n")

# ---------------------------------------------------------------- data
schema = StructType([
    StructField("order_id",   IntegerType(), False),
    StructField("order_date", DateType(),    True),
    StructField("region",     StringType(),  True),
    StructField("product",    StringType(),  True),
    StructField("qty",        IntegerType(), True),
    StructField("unit_price", DoubleType(),  True),
])
rows = [
    (1001, date(2026, 10, 1), "South", "Bearing",   120, 45.0),
    (1002, date(2026, 10, 1), "North", "Gear",       40, 310.0),
    (1003, date(2026, 10, 2), "South", "Shaft",      15, 980.0),
    (1004, date(2026, 10, 3), "West",  "Bearing",   200, 44.5),
    (1005, date(2026, 10, 3), "East",  "Coupling",   60, 150.0),
    (1006, date(2026, 10, 4), "North", "Shaft",      10, 995.0),
    (1007, date(2026, 10, 5), "South", "Gear",       35, 305.0),
    (1008, date(2026, 10, 6), "West",  "Coupling",   80, 148.0),
    (1009, date(2026, 10, 7), "East",  "Bearing",   150, 46.0),
    (1010, date(2026, 10, 8), "South", "Coupling",   25, 152.0),
]
df = spark.createDataFrame(rows, schema)

# transformation (lazy - nothing runs yet)
df = (df.withColumn("amount", F.round(F.col("qty") * F.col("unit_price"), 2))
        .withColumn("month", F.date_format("order_date", "yyyy-MM")))

print("== Schema ==")
df.printSchema()
print("== Data (action: show) ==")
df.show(truncate=False)

# ---------------------------------------------------------------- write parquet
(df.write
   .mode("overwrite")              # overwrite | append | ignore | error
   .partitionBy("region")          # one sub-folder per region
   .option("compression", "snappy")
   .parquet(OUT))
print(f"Parquet written to: {OUT}\n")

print("== Files on disk ==")
for root, _, files in os.walk(OUT):
    for name in files:
        if name.endswith(".parquet"):
            p = os.path.join(root, name)
            print(f"  {os.path.relpath(p, OUT):70s} {os.path.getsize(p):>7} bytes")
print()

# ---------------------------------------------------------------- read back
sales = spark.read.parquet(OUT)      # schema comes from the parquet footer
print("== Schema read from Parquet (region restored from folder name) ==")
sales.printSchema()

print("== Partition pruning: only region=South folder is scanned ==")
south = sales.filter(F.col("region") == "South")
south.show()
south.explain()   # look for PartitionFilters: [... (region = South)]

print("== Aggregation: revenue by region ==")
(sales.groupBy("region")
      .agg(F.count("*").alias("orders"),
           F.sum("qty").alias("units"),
           F.round(F.sum("amount"), 2).alias("revenue"))
      .orderBy(F.desc("revenue"))
      .show())

print("== Spark SQL on the Parquet data ==")
sales.createOrReplaceTempView("sales")
spark.sql("""
    SELECT product,
           SUM(qty)               AS units,
           ROUND(AVG(unit_price),2) AS avg_price,
           ROUND(SUM(amount),2)   AS revenue
    FROM sales
    GROUP BY product
    ORDER BY revenue DESC
""").show()

# ---------------------------------------------------------------- more actions
print("count()   :", sales.count())
print("first()   :", sales.orderBy("order_id").first())
print("collect() :", [r.order_id for r in sales.filter("amount > 10000").collect()])

# Parquet -> pandas (uses pyarrow)
print("\n== toPandas() ==")
print(sales.orderBy("order_id").limit(5).toPandas())

spark.stop()
print("\nDone.")
