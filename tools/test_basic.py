#!/usr/bin/env python3
import os
import subprocess
import sys

print("🔧 Basic Environment Test")
print("=" * 30)

print(f"Python version: {sys.version}")
print(f"Current working directory: {os.getcwd()}")

# Test subprocess
try:
    result = subprocess.run(['echo', 'Hello World'], capture_output=True, text=True, check=True)
    print(f"Subprocess test: {result.stdout.strip()}")
except Exception as e:
    print(f"Subprocess failed: {e}")

# Test basic imports
try:
    import requests
    print("✅ requests available")
except ImportError:
    print("❌ requests not available")

try:
    import pyglossary
    print("✅ pyglossary available")
except ImportError:
    print("❌ pyglossary not available")

print("Test complete")