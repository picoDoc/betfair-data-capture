#!/usr/bin/env python

try :
	import requests
except ImportError :
	print('ERROR: Could not import requests module.  Please check if it is installed.')
	exit()
import os
import sys
import json

if sys.argv[1] == 'login' :
	# parse command line parameters
	app_key = sys.argv[2]
	json_str = sys.argv[3]
	# set-up the path to the certificates
	certpath = os.environ['KDBCONFIG'] + '/certificates/'
	certpath_slashes = certpath.replace( '\\' , '/' )
	# create header
	headers = {'X-Application': app_key , 'content-type': 'application/x-www-form-urlencoded'}
	url = 'https://identitysso.betfair.com/api/certlogin'
	# send off the request
	resp = requests.post(url, data=json.loads(json_str) , cert=( certpath_slashes + 'client-2048.crt', certpath_slashes + 'client-2048.key'), headers=headers)
elif sys.argv[1] == 'data' :
	# parse command line parameters
	app_key = sys.argv[2]
	session_token = sys.argv[3]
	json_str = sys.argv[4]
	# define the headers
	headers = {'X-Application': app_key, 'X-Authentication': session_token, 'content-type': 'application/json'}
	# definer the url
	url = 'https://api.betfair.com/exchange/betting/json-rpc/v1'
	# call the betfair api and print the json string to stdout
	resp = requests.post(url, data=json_str , headers=headers)
elif sys.argv[1] == 'keepAlive' :
	# parse command line parameters
	app_key = sys.argv[2]
	session_token = sys.argv[3]
	# define the headers
	headers = {'X-Application': app_key, 'X-Authentication': session_token, 'Accept' : 'application/json' }
	# definer the url
	url = 'https://identitysso.betfair.com/api/keepAlive'
	# call the betfair api and print the json string to stdout
	resp = requests.post(url, headers=headers)
elif sys.argv[1] == 'logout' :
	# parse command line parameters
	app_key = sys.argv[2]
	session_token = sys.argv[3]
	# define the headers
	headers = {'X-Application': app_key, 'X-Authentication': session_token, 'Accept' : 'application/json' }
	# definer the url
	url = 'https://identitysso.betfair.com/api/logout'
	# call the betfair api and print the json string to stdout
	resp = requests.post(url, headers=headers)
else :
	print('ERROR: Command line parameters invalid.  Exiting script...')
	exit()

if resp.status_code == 200:
	resp_json = json.dumps(resp.json())
	# deal with unicode characters (can't be handled in kdb+ < 3.3)
	if sys.version_info[0] > 2 :
		resp_json = bytes(resp_json, "utf-8").decode("unicode_escape") 
	else :
		resp_json = resp_json.decode('unicode_escape').encode('ascii','ignore')
	print(resp_json)
else:
	print('ERROR: Request failed, status code returned : ' + str(resp.status_code))
  
