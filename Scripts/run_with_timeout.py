#!/usr/bin/env python3
"""Run a command with a wall-clock deadline and terminate its process group."""
import argparse
import os
import signal
import subprocess
import sys

parser = argparse.ArgumentParser()
parser.add_argument("seconds", type=float)
parser.add_argument("command", nargs=argparse.REMAINDER)
args = parser.parse_args()
if args.seconds <= 0 or not args.command:
    parser.error("A positive timeout and command are required.")
process = subprocess.Popen(args.command, start_new_session=True)
try:
    code = process.wait(timeout=args.seconds)
except subprocess.TimeoutExpired:
    print(f"Deadline exceeded after {args.seconds:g} seconds.", file=sys.stderr)
    os.killpg(process.pid, signal.SIGTERM)
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait()
    code = 124
except KeyboardInterrupt:
    os.killpg(process.pid, signal.SIGINT)
    process.wait()
    code = 130
sys.exit(code)
