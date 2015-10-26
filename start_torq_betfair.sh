# Load the environment
. ./setenv.sh

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$KDBLIB/l32

##### EMAILS #####
# this is where the emails will be sent to 
# export DEMOEMAILRECEIVER=user@torq.co.uk

# also set the email server configuration in config/settings/default.q
##### END EMAILS #####

# launch the discovery service
echo 'Starting discovery proc...'
q torq.q -load code/processes/discovery.q  -proctype discovery -procname discovery1 -localtime -U config/passwords/accesslist.txt </dev/null >$KDBLOG/torqdiscovery.txt 2>&1 &

# launch the tickerplant, rdb, hdb
echo 'Starting tp...'
q code/processes/tickerplant.q database $KDBHOME/hdb -proctype tickerplant -procname tickerplant1 -localtime -U config/passwords/accesslist.txt </dev/null >$KDBLOG/torqtp.txt 2>&1 &

echo 'Starting rdb...'
q torq.q -load code/processes/rdb.q -proctype rdb -procname rdb1 -localtime -U config/passwords/accesslist.txt 1 -g 1 -T 30 </dev/null >$KDBLOG/torqrdb.txt 2>&1 &

echo 'Starting hdb1...'
q torq.q -load hdb/database -localtime -proctype hdb -procname hdb1 -U config/passwords/accesslist.txt 1 -g 1 -T 60 -w 4000 </dev/null >$KDBLOG/torqhdb1.txt 2>&1 &
echo 'Starting hdb2...'
q torq.q -load hdb/database -localtime -proctype hdb -procname hdb2 -U config/passwords/accesslist.txt 1 -g 1 -T 60 -w 4000 </dev/null >$KDBLOG/torqhdb2.txt 2>&1 &

# launch the gateway
echo 'Starting gw...'
q torq.q -load code/processes/gateway.q -proctype gateway -procname gateway1 -localtime -U config/passwords/accesslist.txt 1 -g 1 -w 4000 </dev/null >$KDBLOG/torqgw.txt 2>&1 &

# launch the monitor
echo 'Starting monitor...'
q torq.q -load code/processes/monitor.q -proctype monitor -procname monitor1 -localtime 1 </dev/null >$KDBLOG/torqmonitor.txt 2>&1 &

# launch the reporter
echo 'Starting reporter...'
q torq.q -load code/processes/reporter.q -proctype reporter -procname reporter1 -localtime -U config/passwords/accesslist.txt 1 </dev/null >$KDBLOG/torqreporter.txt 2>&1 &

# launch housekeeping
echo 'Starting housekeeping proc...'
q torq.q -load code/processes/housekeeping.q -proctype housekeeping -procname housekeeping1 -localtime -U config/passwords/accesslist.txt </dev/null >$KDBLOG/torqhousekeeping.txt 2>&1 &

# launch sort processes
echo 'Starting sorting proc...'
q torq.q -load code/processes/wdb.q -proctype sort -procname sort1 -localtime -U config/passwords/accesslist.txt 1 -g 1 </dev/null >$KDBLOG/torqsort.txt 2>&1 & # sort process

# launch wdb
echo 'Starting wdb...'
q torq.q -load code/processes/wdb.q -proctype wdb -procname wdb1 -localtime -U config/passwords/accesslist.txt 1 -g 1 </dev/null >$KDBLOG/torqwdb.txt 2>&1 &  # pdb process

# launch compress
echo 'Starting compression proc...'
q torq.q -load code/processes/compression.q  -proctype compression -procname compression1 -localtime </dev/null >$KDBLOG/torqcompress1.txt 2>&1 &  # compression process

# launch compress
echo 'Starting requestor proc...'
q torq.q -load code/processes/requestor.q -proctype requestor -procname requestor1 -localtime </dev/null >$KDBLOG/torqrequestor1.txt 2>&1 &
