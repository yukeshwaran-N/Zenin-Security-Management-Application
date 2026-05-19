import os
import re

dir_path = '/Users/apple/Desktop/Everything/security_patrol_app/lib'

replacements = [
    (r'Duration\(milliseconds:\s*\d+\)', r'Duration(milliseconds: 100)'),
    (r'Duration\(milliseconds:\s*\d+ \+ \(index \* \d+\)\)', r'Duration(milliseconds: 50 + (index * 20))'),
]

for root, _, files in os.walk(dir_path):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r') as f:
                content = f.read()
            
            new_content = content
            for old, new in replacements:
                new_content = re.sub(old, new, new_content)
                
            if content != new_content:
                with open(filepath, 'w') as f:
                    f.write(new_content)
                print(f"Updated {filepath}")
