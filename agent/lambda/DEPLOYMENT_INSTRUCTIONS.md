# Lambda Layer Build Instructions

## Prerequisites
- Python 3.11 or higher
- pip3

## Build Lambda Layer

1. Navigate to the lambda directory:
```bash
cd assets/agent/lambda
```

2. Install required tools:
```bash
pip3 install pipreqs pip-licenses
```

3. Generate requirements file (if not already present):
```bash
pipreqs .
```

4. Install dependencies and generate license information:
```bash
pip3 install -r requirements.txt
pip-licenses > licenses.txt
```

5. Create the Lambda layer:
```bash
# Create build directory
mkdir -p build/python

# Install dependencies
pip3 install -r requirements.txt -t build/python/

# Create zip
cd build && zip -r ../python_os_req_auth.zip python/ && cd ..

# Clean up
rm -rf build
```

The generated `python_os_req_auth.zip` file can be used as your Lambda layer.

## Current Dependencies and Licenses

```
Name                Version      License                              
boto3               1.34.0       Apache Software License              
botocore            1.34.162     Apache Software License              
certifi             2025.6.15    Mozilla Public License 2.0 (MPL 2.0) 
charset-normalizer  3.4.2        MIT License                          
idna                3.10         BSD License                          
jmespath            1.0.1        MIT License                          
python-dateutil     2.9.0.post0  Apache Software License; BSD License 
requests            2.31.0       Apache Software License              
s3transfer          0.9.0        Apache Software License              
six                 1.17.0       MIT License                          
typing_extensions   4.8.0        Python Software Foundation License   
urllib3             2.5.0        UNKNOWN
```