#!/usr/bin/python3

# Replace identical files with links to single copy

import hashlib
import os

# Compute the MD5 of a file
def gethash(file):
    hasher = hashlib.md5()
    with open(file, "rb") as f:
        buf = f.read()
        hasher.update(buf)
    return hasher.hexdigest()

# Start with an empty dictionary
hashmap = {}

# Recursively visit all files in the directory being scanned
for rootdir, dirs, files in os.walk("/home1/pbravakos/Software"):
    for f in files:
        path = os.path.join(rootdir, f)
        # Skip short files and symlinks.
        if os.path.islink(path) or os.stat(path).st_size < 1024:
            continue
        hash = gethash(path)
        if hash in hashmap:
            matching = hashmap[hash]
            # We have found a pair of identical files
            # If they are links to the same file there is nothing to do
            if os.stat(path).st_ino == os.stat(matching).st_ino:
                print("%s, %s are links to same file" % (path, matching))
                continue
            # Otherwise, delete the new file and link the name to the old one
            else:
                #os.unlink(path)
                #os.link(matching, path)
                print("%s same as %s" % (path, matching))
        else:
            # Add the hash of the new file to the dictionary
            hashmap[hash] = path

