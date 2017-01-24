#!/usr/bin/env python

import string

if __name__ == "__main__":

    checked_options = []
    with open("./configs/docker-check-odroidc2.txt") as checked:
        for dl in checked:
            dc = string.strip(dl)
            if dc.startswith('- CONFIG_') and "enabled" in dc:
                checked_options.append(dc.split(":")[0].replace("- ", ""))
    #print checked_options, "\n\n"

    # kernel config captured from /proc/config.z
    captured_options = []
    with open("./configs/captured-config-odroidc2.txt") as captured:
        for cl in captured:
            cc = string.strip(cl)
            cfg = ""
            if cc.endswith(' is not set'):
                cfg = cc.replace(' is not set', '').replace('# ', '')

            elif cc.startswith('CONFIG_'):
                cfg = string.strip(cc.split('=')[0])

            if len(cfg):
                opt_found = False
                for co in checked_options:
                    if cfg == co:
                        opt_found = True
                        break

                if opt_found:
                    captured_options.append(cfg + "=y")
                else:
                    captured_options.append(cc)
            else:
                captured_options.append(cc)

    with open("./configs/combined-config-odroidc2.txt", "w") as combined:
        for co in captured_options:
            combined.write(co + "\n")