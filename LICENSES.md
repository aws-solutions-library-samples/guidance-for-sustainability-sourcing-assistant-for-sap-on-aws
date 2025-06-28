# License Information

## Project License
This project is licensed under the Apache License 2.0. See LICENSE file for details.

## Third-Party Dependencies

### Python Packages Used in Lambda Layer

| Package | Version | License |
|---------|---------|---------|
| requests | 2.31.0 | Apache Software License |
| opensearch-py | 2.4.2 | Apache Software License |
| urllib3 | >=1.21.1,<3 | MIT License |
| certifi | >=2017.4.17 | Mozilla Public License 2.0 (MPL 2.0) |
| charset-normalizer | >=2,<4 | MIT License |
| idna | >=2.5,<4 | BSD License |
| six | >=1.9.0 | MIT License |
| python-dateutil | >=2.1 | Apache Software License; BSD License |

### Commands to Generate License Information

```bash
# Install dependencies in virtual environment
python3 -m venv venv
source venv/bin/activate
pip install -r agent/lambda/requirements.txt pip-licenses

# Generate license report
pip-licenses --format=plain > licenses.txt

# Deactivate virtual environment
deactivate
```

### License Compliance Notes

- **Apache Software License**: Compatible with commercial use, modification, and distribution
- **MIT License**: Permissive license allowing commercial use
- **Mozilla Public License 2.0**: Copyleft license requiring source code disclosure for modifications
- **BSD License**: Permissive license similar to MIT

All dependencies are compatible with commercial AWS deployments.