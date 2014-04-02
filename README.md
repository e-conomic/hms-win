
### hms-win


Windows client for hms [https://github.com/mafintosh/hms]

Includes a simple node server that redirect the actual work on the windows box to a series of powershell scripts.

The server can be started by 

	node index.js

The powershell scripts are tested by pester. If you have pester installed the tests can be run in powershell from the tests folder, with the command:
	
	Invoke-Pester

