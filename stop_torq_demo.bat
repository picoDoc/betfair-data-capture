REM  Load the environment
set KDBHOME=%cd%
set KDBCONFIG=%KDBHOME%\config
set KDBCODE=%KDBHOME%\code
set KDBLOG=%KDBHOME%\logs
set KDBHTML=%KDBHOME%\html
set KDBLIB=%KDBHOME%\lib
set KDBBIN=%KDBHOME%\bin
set PATH=%PATH%;%KDBLIB%\w32

set KDBBASEPORT=30000

REM kill all torq procs
start "kill" q torq.q -load code/processes/kill.q -proctype kill -procname kill1 -.servers.CONNECTIONS feed rdb tickerplant hdb gateway housekeeping monitor discovery wdb sort reporter compression requestor
