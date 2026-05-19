import re

files = [
    'lib/screens/so/manage_checkpoints_screen.dart',
    'lib/screens/so/supervisor_list.dart',
    'lib/screens/so/add_supervisor_screen.dart',
    'lib/screens/so/so_dashboard.dart'
]

for path in files:
    try:
        with open(path, 'r') as f:
            content = f.read()
        
        # Remove 'const Text(TranslationHelper' -> 'Text(TranslationHelper'
        content = content.replace("const Text(TranslationHelper", "Text(TranslationHelper")
        
        # Also remove 'const SnackBar(content: Text(TranslationHelper' -> 'SnackBar(content: Text(TranslationHelper'
        content = content.replace("const SnackBar(content: Text(TranslationHelper", "SnackBar(content: Text(TranslationHelper")
        
        # Also remove 'const SnackBar(content: const Text(TranslationHelper' -> 'SnackBar(content: Text(TranslationHelper'
        content = content.replace("const SnackBar(content: const Text(TranslationHelper", "SnackBar(content: Text(TranslationHelper")

        # Also remove 'const Text((TranslationHelper' -> 'Text((TranslationHelper'
        content = content.replace("const Text((TranslationHelper", "Text((TranslationHelper")

        with open(path, 'w') as f:
            f.write(content)
        print("Processed " + path)
    except FileNotFoundError:
        pass
