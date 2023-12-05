import json
import yaml

with open('azure_vm_config.yaml', 'r') as yaml_file:
    yaml_data = yaml.safe_load(yaml_file)

with open('azure_vm_config.json', 'w') as json_file:
    json.dump(yaml_data, json_file, indent=4)

