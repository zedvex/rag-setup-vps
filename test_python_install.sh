#!/bin/bash

# Simple test script for Python 3.11 installation methods
echo "🐍 Testing Python 3.11 Installation Methods for AlmaLinux 9"
echo "============================================================"
echo

# Method 1: Check AppStream module
echo "Method 1: Checking AppStream module availability..."
if sudo dnf module list python311 2>/dev/null | grep -q python311; then
    echo "✅ AppStream python311 module is available"
    sudo dnf module list python311
else
    echo "❌ AppStream python311 module not available"
fi
echo

# Method 2: Check EPEL packages
echo "Method 2: Checking EPEL package availability..."
if sudo dnf list python3.11 2>/dev/null | grep -q python3.11; then
    echo "✅ python3.11 package available"
    sudo dnf list python3.11
else
    echo "❌ python3.11 package not available"
fi
echo

# Method 3: Check IUS repository
echo "Method 3: Checking IUS repository..."
if curl -s https://repo.ius.io/ius-release-el9.rpm > /dev/null; then
    echo "✅ IUS repository is accessible"
    echo "   URL: https://repo.ius.io/ius-release-el9.rpm"
else
    echo "❌ IUS repository not accessible"
fi
echo

# Method 4: Check if we can download Python source
echo "Method 4: Checking Python source availability..."
if curl -s --head https://www.python.org/ftp/python/3.11.8/Python-3.11.8.tgz | head -n 1 | grep -q "200 OK"; then
    echo "✅ Python 3.11.8 source is available for compilation"
    echo "   URL: https://www.python.org/ftp/python/3.11.8/Python-3.11.8.tgz"
else
    echo "❌ Python 3.11.8 source not accessible"
fi
echo

# Current Python versions
echo "Current Python installations:"
echo "System Python 3: $(python3 --version 2>/dev/null || echo 'Not found')"
echo "Python 3.11: $(python3.11 --version 2>/dev/null || echo 'Not found')"
echo

echo "🎯 Recommendation:"
echo "Run './setup_laika_almalinux.sh install' to automatically try all methods"
echo "and install Python 3.11 with the best available option for your system." 