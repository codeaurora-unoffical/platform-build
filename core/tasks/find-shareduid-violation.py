#!/usr/bin/env python3
#
# Copyright (C) 2019 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
import os
import subprocess
from glob import glob
from collections import defaultdict
import sys
import json

if len(sys.argv) < 3:
    product_out = os.environ["PRODUCT_OUT"]
    aapt = "aapt2"
else:
    product_out = sys.argv[1]
    aapt = sys.argv[2]

def make_aapt_cmd(file):
    cmds = [aapt + ' dump ' + file + ' --file AndroidManifest.xml',
            aapt + ' dump xmltree ' + file + ' --file AndroidManifest.xml']
    return " || ".join(cmds)

def extract_shared_uid(file):
    manifest = subprocess.check_output(make_aapt_cmd(file), shell=True).decode().split('\n')
    for l in manifest:
        if "sharedUserId" in l:
            return l.split('"')[-2]
    return None


partitions = ["system", "vendor", "product"]

shareduid_app_dict = defaultdict(list)

for p in partitions:
    for f in glob(os.path.join(product_out, p, "*", "*", "*.apk")):
        apk_file = os.path.basename(f)
        shared_uid = extract_shared_uid(f)

        if shared_uid is None:
            continue
        shareduid_app_dict[shared_uid].append((p, apk_file))


output = defaultdict(lambda: defaultdict(list))

for uid, app_infos in shareduid_app_dict.items():
    partitions = {p for p, _ in app_infos}
    if len(partitions) > 1:
        for part in partitions:
            output[uid][part].extend([a for p, a in app_infos if p == part])

print(json.dumps(output, indent=2, sort_keys=True))
