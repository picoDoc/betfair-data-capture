# load env script
. ./setenv.sh

#kill requestor proc
echo 'Shutting down requestor...'
q torq.q -load code/processes/kill.q -p 30100 -.servers.CONNECTIONS requestor </dev/null >$KDBLOG/torqkill.txt 2>&1 

#and start it up again
echo 'Starting requestor proc...'
q torq.q -load code/processes/requestor.q -localtime -p 31099 1 </dev/null >$KDBLOG/torqrequestor1.txt 2>&1 &

