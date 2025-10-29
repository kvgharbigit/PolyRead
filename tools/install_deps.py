#!/usr/bin/env python3
"""
Install and verify dependencies for StarDict conversion
"""

import subprocess
import sys
import os

def install_package(package):
    """Install a Python package using pip"""
    try:
        print(f"📦 Installing {package}...")
        result = subprocess.run([sys.executable, "-m", "pip", "install", package], 
                              capture_output=True, text=True, check=True)
        print(f"✅ {package} installed successfully")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to install {package}: {e}")
        return False

def verify_import(package):
    """Verify a package can be imported"""
    try:
        __import__(package)
        print(f"✅ {package} import successful")
        return True
    except ImportError as e:
        print(f"❌ {package} import failed: {e}")
        return False

def main():
    print("🔧 Setting up dependencies for StarDict conversion")
    print("=" * 50)
    
    # Required packages
    packages = [
        "requests",
        "pyglossary",
    ]
    
    # Install packages
    all_success = True
    for package in packages:
        if not install_package(package):
            all_success = False
    
    if not all_success:
        print("❌ Some packages failed to install")
        return 1
    
    print("\n🧪 Verifying imports...")
    
    # Verify imports
    for package in packages:
        if not verify_import(package):
            all_success = False
    
    # Special test for PyGlossary
    try:
        from pyglossary import Glossary
        print("✅ PyGlossary Glossary class import successful")
    except ImportError as e:
        print(f"❌ PyGlossary Glossary import failed: {e}")
        all_success = False
    
    if all_success:
        print("\n✅ ALL DEPENDENCIES READY!")
        return 0
    else:
        print("\n❌ DEPENDENCY SETUP FAILED!")
        return 1

if __name__ == "__main__":
    sys.exit(main())