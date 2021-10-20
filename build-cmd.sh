#!/usr/bin/env bash

# turn on verbose debugging output for logs.
# exec 4>&1; export BASH_XTRACEFD=4; set -x
# make errors fatal
set -e
# bleat on references to undefined shell variables
set -u

echo "1.0" > VERSION.txt

# this script should be executed from the build output directory (stage)
# case "$AUTOBUILD_PLATFORM" in
	# linux*)
		../discord-rpc/build.py --clean
		mkdir -p include
		cp -r ../discord-rpc/builds/install/linux-static/include ./include/discord_rpc
		mkdir -p lib
		cp -r ../discord-rpc/builds/install/linux-static/lib ./lib/release
		mkdir LICENSES -p
		cp ../discord-rpc/LICENSE LICENSES/discord_rpc.txt
		autobuild manifest clear
		# mkdir -p include/
		# cp -r "../discord/cpp" "include/discord"
		# cp -r "../LICENSES" "LICENSES/"
		# Maybe make one package for each architecture and
		# copy the relevant libs then?
		# cp -r "../discord/lib/x86_64" "lib/release"
		autobuild manifest add include/discord_rpc/*
		autobuild manifest add lib/release/*
		autobuild manifest add LICENSES/*
		autobuild manifest add VERSION.txt
		
# esac
