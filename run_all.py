"""Run every query in order against the Owner order export and print the results.
Usage: python run_all.py /path/to/Untitled_2026-11-22-2124.csv
Requires: pip install duckdb pandas"""
import sys, glob, os, duckdb
csv = sys.argv[1]
con = duckdb.connect()
here = os.path.dirname(os.path.abspath(__file__))
for path in sorted(glob.glob(os.path.join(here, '*.sql'))):
    print(f"\n===== {os.path.basename(path)} =====")
    sql = open(path).read().replace('{CSV}', csv)
    sql = '\n'.join(l for l in sql.splitlines() if not l.strip().startswith('--'))  # drop comment lines first
    for stmt in [s.strip() for s in sql.split(';')]:
        body = stmt
        if not body: continue
        res = con.execute(body)
        if body.upper().startswith(('SELECT', 'WITH')):
            print(res.df().to_string(index=False)); print()
