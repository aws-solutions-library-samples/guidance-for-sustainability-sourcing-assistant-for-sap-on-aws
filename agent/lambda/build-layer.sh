#!/bin/bash

# Build Lambda layer for SAP Assistant
# This script creates a Lambda layer with required Python packages

set -e

echo "Building Lambda layer..."

# Create temporary directory
mkdir -p layer/python

# Install packages
pip3 install -r requirements.txt -t layer/python/

# Create zip file
cd layer
zip -r ../python_os_req_auth.zip .
cd ..

# Clean up
rm -rf layer

echo "Layer built successfully: python_os_req_auth.zip"