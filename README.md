# TorQ-Betfair-Starter-Pack
This is a simple example of a market data capture system using sports exchange (betting) data from betfair.com.  This is installed on top of the base TorQ package, and includes a version of [kdb+tick](http://code.kx.com/wsvn/code/kx/kdb+tick).

## Prerequisites

To get this framework up and running in a unix environment you need two things:

1. The [free 32 bit version of kdb+](http://kx.com/software-download.php) set up and available from the command prompt as q.
2. A betfair.com account with some money in it (need to check exactly what the criteria for getting data are).  I think $5 or something is grand. 


## Set Up

1. Download a zip of the latest version of [TorQ](https://github.com/AquaQAnalytics/TorQ/archive/master.zip)
2. Download a zip of [this starter pack](https://github.com/AquaQAnalytics/TorQonnect-Betfair/archive/master.zip)
3. Unzip TorQ
4. Unzip the starter pack over the top (this will replace some files)
5. Add account details to config/settings/requestor.q
  - fill in username and password
...
.requestor.username:"me";
...
  - fill in appKey (need more detail on this for sure)
6. Add in the certificates (need more detail and a link here)
7. Add in some event IDs to track
  - where to find the ID (API visualizer)
  - how to add them (details it needs)
8. Run the startup script start_torq_demo.sh to start up the TorQ stack and start collecting data!

## Use

1. Some info on basic gateway queries goes here 


For more information on how to configure and get started, read *TODO*
