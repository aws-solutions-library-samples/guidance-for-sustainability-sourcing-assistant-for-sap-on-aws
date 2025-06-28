# Lambda Layer Build Instructions

## Prerequisites
- Python 3.11 or higher
- pip package manager
- zip utility

## Build Lambda Layer

### Option 1: Using the build script
```bash
cd agent/lambda
chmod +x build-layer.sh
./build-layer.sh
```

### Option 2: Manual build
```bash
cd agent/lambda
mkdir -p layer/python
pip3 install -r requirements.txt -t layer/python/
cd layer
zip -r ../python_os_req_auth.zip .
cd ..
rm -rf layer
```

## Generate License Information
```bash
pip install pip-licenses
pip-licenses --format=plain > licenses.txt
```

## Dependencies
- requests==2.31.0 - HTTP library for SAP API calls
- opensearch-py==2.4.2 - OpenSearch client for vector operations