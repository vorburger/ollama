#!/usr/bin/env python3
import subprocess
import sys
from urllib.parse import urlparse
from git import Repo
# TODO - add argpare and make this more configurable 
# - force flag becomes optional
# - build or test as

# Note: remote repo will need this run once:
# git config --local receive.denyCurrentBranch updateInstead
repo = Repo(".")
# GoCmd = "/usr/local/go/bin/go" 
GoCmd = "go" 

if repo.is_dirty():
    print("Tree is dirty.  Commit your changes before running this script")
    sys.exit(1)

if len(sys.argv) != 2:
    print("Please specify the remote name: " + ', '.join([r.name for r in repo.remotes]))
    sys.exit(1)
remote_name = sys.argv[1]

remote = {r.name: r for r in repo.remotes}[remote_name]
raw_url = list(remote.urls)[0]
url = urlparse(raw_url)
# Windows urls don't quite parse properly
if url.scheme == "" and url.netloc == "":
    url = urlparse("ssh://" + raw_url)
print("URL: " + str(url))
netloc = url.netloc.split(":")[0]
path = url.path
branch_name = repo.active_branch.name

print("Force pushing content to remote...")
# Use with care given the force push
remote.push(force=True).raise_if_error()

print("Ensuring correct branch checked out on remote via ssh...")
subprocess.check_call(['ssh', netloc, 'cd', path, ';', 'git', 'checkout', branch_name])


# TODO - add some hardening to try to figure out how to set up the path properly
# subprocess.check_call(['ssh', netloc, 'cd', path, ';', 'env'])
# TODO - or consider paramiko maybe

print("Performing generate")
subprocess.check_call(['ssh', netloc, 'cd', path, ';', GoCmd, 'generate', './...'])

print("Building")
subprocess.check_call(['ssh', netloc, 'cd', path, ';', GoCmd, 'build', '.'])

