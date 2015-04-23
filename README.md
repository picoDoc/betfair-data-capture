# TorQonnect-Betfair
This is a simple example of a market data capture system using sports exchange (betting) data from betfair.com.  This is installed on top of the base TorQ package, and includes a version of [kdb+tick](http://code.kx.com/wsvn/code/kx/kdb+tick).

## Prerequisites

To get this framework up and running in a unix environment you need two things:

1. A unix environement with wget and curl installed (this TorQonnect package **does not currently work in windows**).
1. The [free 32 bit version of kdb+](http://kx.com/software-download.php) set up and available from the command prompt as q.
2. A betfair.com account. If you don't already have an account you can get one [here](https://register.betfair.com/account/registration).


## Set Up

* Download a zip of the latest version of [TorQ](https://github.com/AquaQAnalytics/TorQ/archive/master.zip)
* Download a zip of [this starter pack](https://github.com/AquaQAnalytics/TorQonnect-Betfair/archive/master.zip)
* Unzip TorQ
* Unzip the starter pack over the top (this will replace some files)
* Add some account details to *config/settings/requestor.q*
    - fill in betfair.com username and password

        ```
        .requestor.username:"me";
        .requestor.password:"password";
        ```

    - Betfair also requires something called an **Application Key**.  You can find more information on this and how to obtain it [here](https://api.developer.betfair.com/services/webapps/docs/display/1smk3cen4v3lu3yomq5qye0ni/Application+Keys).  If you follow the instructions listed under **How to Create An Application Key** betfair will give you one.  Make sure you are logged into your betfair account while you follow the instructions and the **sessionToken** will be automatically filled in, making you life alot easier.  For the **Application name** you can choose anything you like.
    - Once you've followed the steps to create an application key, in the API-NG visualizer click **getDeveloperAppKeys** then **Execute**.  This will return two keys, one with a delay and one without.  You probably want the one without.  Add this info to *requestor.q*.

        ```
        .requestor.appKey:"eQud5Jawxlq2CuLQ";
        ```

* Since this framework will collect data automatically it requires a non-interactive authorised login method.  Details of how to set this up with Betfair are [here](https://api.developer.betfair.com/services/webapps/docs/display/1smk3cen4v3lu3yomq5qye0ni/Non-Interactive+%28bot%29+login).  Follow the instructions in the sections **Creating a Self Signed Certificate** and **Linking the Certificate to Your Betfair Account**.  This will generate 3 files:
    - client-2048.key
    - client-2048.csr
    - client-2048.crt
    - Copy all 3 of these files into the *config/certificates* folder.
* Finally we need to add some events to collect data on!  In *config/settings/requestor.q* there are a few examples provided and commented out.  First we define a table that stores the events we want to monitor and their details:

    ```
    .requestor.markets:([]market:();marketId:();start:();end:();interval:());
    ```

    then we add rows to this table:

    ```
    `.requestor.markets insert (`PremierLeague;`1.113659986;.z.p;0Wp;00:15:00.000000000);
    ```

    This entry will collect available quotes and trading data on the English Premier League overall champion every 15 minutes, starting immediately.  So lets go over the meaning of each piece of information in this table:
    - **market** is simply an identifier for the market, you can use whatever name you like
    - **marketId** is the most important piece of information, this is betfair's unique market identifier.  See below on where to find these
    - **start** This tells TorQ when to start collecting data on this market (.z.p for immediate start)
    - **end** This tell TorQ when to stop collecting data on this market
    - **interval** This tells TorQ how often to collect data on this market
* The best way to find the marketId for a particular event is using the betfair [Betting API visualiser](https://developer.betfair.com/visualisers/api-ng-sports-operations/).  Under **listMarketCatalogue** you can search through the available markets by name, volume traded, sport etc.  Again if you're logged in before you click this the **App Key** and **Session Token** will autofill.
* Once you have a few markets setup to collect data on, all that's left to do is run the startup script to start up the TorQ stack and start collecting data!

    ```
    sh start_torq_demo.sh
    ```

## Use

* Once you have some data in the system there are some basic queries on the gateway.  
    - You can run to get a list of available events in your database: 

        ```
        getEvents[]
        ```
    - To return the mid run:
        
        ```
        getMid enlist[`sym]!enlist[`$"Scotland v Ireland"]
        ```
    - To return the mid pivoted (so the outcomes are columns rather than rows):

        ```
        getMidPivot enlist[`sym]!enlist[`$"Scotland v Ireland"]
        ```
* I'm going to add more details in here when I can be assed...


For more information on how to configure and get started, read *TODO*
