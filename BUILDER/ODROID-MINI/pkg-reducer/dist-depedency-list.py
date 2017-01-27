#!/usr/bin/python

import subprocess, string

if __name__ == "__main__":
	#subprocess.call(["/bin/bash", "read-dep-pkgs.sh", "dist-target.manifest", "dist-packages.list"])

	deps = []
	with open("dist-packages.list") as dpl:
		for dp in dpl:
			if "Depends:" in dp:
				d = string.strip(dp.split(':')[1])
				if not d in deps:
					deps.append(d)

	deps = sorted(deps, key=str.lower)
	with open("dist-packages-sorted.list", "w") as dps:
		for d in deps:
			dps.write(d + "\n")