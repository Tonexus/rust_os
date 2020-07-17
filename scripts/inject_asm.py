# script that injects segmented stack code into rust asm
# TODO actual injecting, for now, just copies and strips hash

import sys
import os.path
import re
import shutil

if len(sys.argv) <= 2:
    print("Must have at least one source and a target directory")
    sys.exit(1)

asm_files = sys.argv[1:-1]
target_dir = sys.argv[-1]

for file in asm_files:
    shutil.copyfile(file, os.path.join(target_dir, re.sub(r"-[0-9a-f]+.s", ".s", os.path.basename(file))))
    # shutil.copyfile(file, os.path.join(target_dir, os.path.basename(file)))
    print("TODO: inject asm to {}".format(file))

sys.exit(0)
