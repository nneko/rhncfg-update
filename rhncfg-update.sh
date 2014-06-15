#!/bin/bash
#
# description: Update configuration files on the client for the channels that it is registered (pull) or update (push) files on satellite repo.
# author: Nneko Branche
#
#Copyright (c) 2014 Nneko Branche - Released under the MIT License.
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
#NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

USER=root
RETVAL=0
prog="rhncfg-update"

if ! $( [ "$1" == "push" ] || [ "$1" == "pull" ] );
then
	echo "usage: rhncfg-update.sh [push|pull]";
	exit -1;
fi	

#List files that differ from central repository
modcfgs=( `rhncfg-client verify -o | awk '{print $2}'` );

#Push modified configuration files to the central repo.
if [ "$1" == "push" ];
then
	# List the configuration channels and files registered for this client. Split the list into a {file, channel} hash
	declare -A cfglst;
	while read line; 
	do
		pair=`echo $line | awk '{if($1=="F"){print $2" "$3}}'`;
		OIFS="$IFS";
		IFS=' ';
	    read -a cfgpair <<< "${pair}";
	    IFS="$OIFS";
	    if [[ ${cfgpair[1]} =~ ^/ ]];
    	then
	    	cfglst["${cfgpair[1]}"]="${cfgpair[0]}";
	    else
	    	continue;
	    fi
	done < <(rhncfg-client list)

	#Find the channel associated with the modified file and update the central repository	
	for cfg in ${modcfgs[@]};
	do
		channel=${cfglst["$cfg"]};
		if [ "$channel" != "" ];
		then
			#Fetch username and password from ~/.rhncfgrc
			if [ -e ~/.rhncfgrc ];
			then
				#Read username and password from file and load into hash userparams
				declare -A userparams;
				while read params;
				do
					OIFS="$IFS";
					IFS=' ';
				    read -a param <<< "${params}";
				    IFS="$OIFS";
			    	userparams["${param[0]}"]="${param[1]}";
				done < <(cat ~/.rhncfgrc|awk -F= '{if($1=="password"||$1=="username"){print $1" "$2}}')

				logger -p daemon.notice -t $prog "updating file $cfg in configuration channel $channel...";
				if [ ${#userparams[@]} -eq 2 ];
				then
					logger -p daemon.notice -t $prog "attempting update using user parameters specified in .rhncfgrc";
					rhncfg-manager update --username ${userparams["username"]} --password ${userparams["password"]} -c $channel $cfg;
				else
					rhncfg-manager update -c $channel $cfg;
				fi
			fi
		fi
	done
fi

#Download modified files from the central repository if node is instructed to pull
if [ "$1" == "client" ];
then
	if [ ${#modcfgs[@]} -gt 1 ];
	then
		for file in ${modcfgs[@]};
		do
			if [ "$file" != "" ] && [ "$file" != "server" ];
			then
				logger -p daemon.notice -t $prog "deploying $file from central repository...";
				rhncfg-client get $file;
			fi
		done
	fi
fi