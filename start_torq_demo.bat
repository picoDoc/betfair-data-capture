REM  Load the environment
set KDBHOME=%cd%
set KDBCONFIG=%KDBHOME%\config
set KDBCODE=%KDBHOME%\code
set KDBLOG=%KDBHOME%\logs
set KDBHTML=%KDBHOME%\html
set KDBLIB=%KDBHOME%\lib
set KDBBIN=%KDBHOME%\bin
set PATH=%PATH%;%KDBLIB%\w32

REM  EMAILS #####
REM this is where the emails will be sent to 
REM  export DEMOEMAILRECEIVER=user@torq.co.uk

REM  also set the email server configuration in config/settings/default.q
REM  END EMAILS #####

REM  launch the discovery service
REM  'Starting discovery proc...'
start "discovery" q torq.q -load code/processes/discovery.q -localtime -p 31000 -U config/passwords/accesslist.txt 

REM  launch the tickerplant, rdb, hdb
REM  'Starting tp...'
start "tickerplant" q tickerplant.q database hdb -localtime -p 31100 -U config/passwords/accesslist.txt

REM  'Starting rdb...'
start "rdb" q torq.q -load code/processes/rdb.q -localtime -p 31200 -U config/passwords/accesslist.txt -g 1 -T 30

REM  'Starting hdb1...'
start "hdb1" q torq.q -load hdb/database -localtime -p 31300 -U config/passwords/accesslist.txt -g 1 -T 60 -w 4000
REM  'Starting hdb2...'
start "hdb2" q torq.q -load hdb/database -localtime -p 31301 -U config/passwords/accesslist.txt -g 1 -T 60 -w 4000

REM launch the gateway
REM  'Starting gw...'
start "gateway" q torq.q -load code/processes/gateway.q -localtime -p 30000 -U config/passwords/accesslist.txt -g 1 -w 4000

REM launch the monitor
REM 'Starting monitor...'
start "monitor" q torq.q -load code/processes/monitor.q -localtime -p 30200

REM  launch the reporter
REM  'Starting reporter...'
start "reporter" q torq.q -load code/processes/reporter.q -localtime -p 30500 -U config/passwords/accesslist.txt 

REM  launch housekeeping
REM  'Starting housekeeping proc...'
start "housekeeping" q torq.q -load code/processes/housekeeping.q -localtime -p 30400 -U config/passwords/accesslist.txt 

REM  launch sort processes
REM  'Starting sorting proc...'
start "sort" q torq.q -load code/processes/wdb.q -localtime -p 31450 -U config/passwords/accesslist.txt -g 1

REM  launch wdb
REM  'Starting wdb...'
start "wdb" q torq.q -load code/processes/wdb.q -localtime -p 31400 -U config/passwords/accesslist.txt -g 1 

REM  launch compress
REM  'Starting compression proc...'
start "compress" q torq.q -load code/processes/compression.q -localtime -p 30600 

REM  launch compress
REM  'Starting requestor proc...'
start "requestor" q torq.q -load code/processes/requestor.q -localtime -p 31099 
