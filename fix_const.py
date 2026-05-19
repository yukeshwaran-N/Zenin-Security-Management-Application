import re
import os

files = [
    'lib/screens/so/manage_checkpoints_screen.dart',
    'lib/screens/so/supervisor_list.dart',
    'lib/screens/so/add_supervisor_screen.dart',
    'lib/screens/so/so_dashboard.dart'
]

for path in files:
    if os.path.exists(path):
        with open(path, 'r') as f:
            content = f.read()
        
        # Replace `const Text(\n TranslationHelper`
        content = re.sub(r'const\s+Text\s*\(\s*TranslationHelper', r'Text(TranslationHelper', content)
        
        # Replace `const SnackBar(...)` if it contains TranslationHelper
        # This is harder with regex if it spans multiple lines. Let's just remove `const SnackBar` entirely and replace with `SnackBar`
        # Because SnackBars shouldn't be const if their content is not const.
        content = re.sub(r'const\s+SnackBar\s*\(', r'SnackBar(', content)

        with open(path, 'w') as f:
            f.write(content)
        print("Fixed " + path)

