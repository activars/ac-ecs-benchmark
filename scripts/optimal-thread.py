import subprocess
import time
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("thread", help="starting thread number", type=int)
parser.add_argument("username", help="mysql username")
parser.add_argument("password", help="mysql password")
parser.add_argument("hostname", help="mysql hostname")
args = parser.parse_args()

username = args.username
password = args.password
hostname = args.hostname

thread = args.thread or 500
exitcode = 1
confirmation = 1

def benchmark (thread, test_case):
   return "sysbench --db-driver=mysql --threads=%s --events=100000 --mysql-user=%s --mysql-password=%s --mysql-host=%s --mysql-db=foo /usr/local/Cellar/sysbench/1.0.14/share/sysbench/%s.lua --table_size=100000 --tables=3 --rand-type=uniform run" % (thread, username, password, hostname, test_case) 


while exitcode != 0:
  print("================================= READ/WRITE BENCHMARK: %s ======================" % (thread))
  otlp_cmd = benchmark(thread, 'oltp_read_write') 
  index_cmd = benchmark(thread, 'oltp_update_index')

  exitcode = subprocess.call(otlp_cmd, shell=True)
  if exitcode == 0:
    # cool down time
    print("INFO: cool down for the next batch")
    time.sleep(30)
    print("--------------- INDEX BENCHMARK -------------------")
    exitcode = subprocess.call(index_cmd, shell=True)

  if exitcode == 0:
    if confirmation != 0:
      print("INFO: running the same thread test again to confirm ")
      confirmation = confirmation - 1
    else:
      print('SUCCESS: Complete')
      exit(0)
  else:
    print("WARNING: try to find optimial thread again")
    thread = thread - 10

  time.sleep(30)
  





