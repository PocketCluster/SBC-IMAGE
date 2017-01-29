#!/usr/bin/env bash

while read -r t; do
	if [ -f "dist-packages.list" ]; then
		apt-cache depends ${t} >> "dist-packages.list"
	else
		apt-cache depends ${t} > "dist-packages.list"
	fi
done < "dist-target.manifest"
