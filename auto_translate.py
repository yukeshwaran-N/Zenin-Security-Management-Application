import re

files = [
    'lib/screens/so/manage_checkpoints_screen.dart',
    'lib/screens/so/supervisor_list.dart',
    'lib/screens/so/add_supervisor_screen.dart',
]

replacements = {
    # manage_checkpoints_screen.dart
    "'Successfully fetched mobile coordinates!'": "TranslationHelper.translate('fetch_location_success')",
    "'Failed to get location: $e'": "TranslationHelper.translate('fetch_location_failed') + e.toString()",
    "'Checkpoint updated successfully'": "TranslationHelper.translate('checkpoint_updated')",
    "'Checkpoint added successfully'": "TranslationHelper.translate('checkpoint_added')",
    "'An error occurred'": "TranslationHelper.translate('error_occurred')",
    "'Edit Patrol Point'": "TranslationHelper.translate('edit_patrol_point')",
    "'Add Patrol Point'": "TranslationHelper.translate('add_patrol_point')",
    "'Block/Area'": "TranslationHelper.translate('block_area')",
    "'e.g. C4'": "TranslationHelper.translate('eg_c4')",
    "'Required'": "TranslationHelper.translate('required')",
    "'Point/Location'": "TranslationHelper.translate('point_location')",
    "'e.g. Basement'": "TranslationHelper.translate('eg_basement')",
    "'Description'": "TranslationHelper.translate('description')",
    "'Describe details about this checkpoint...'": "TranslationHelper.translate('description_hint')",
    "'COORDINATES (GPS)'": "TranslationHelper.translate('coordinates_gps')",
    "'Get My Location'": "TranslationHelper.translate('get_my_location')",
    "'Latitude'": "TranslationHelper.translate('latitude')",
    "'Longitude'": "TranslationHelper.translate('longitude')",
    "'VALIDATION RADIUS'": "TranslationHelper.translate('validation_radius')",
    "'${_radius.round()} meters'": "\"${_radius.round()}\" + TranslationHelper.translate('meters')",
    "'CHECKLIST / TASKS TO PERFORM'": "TranslationHelper.translate('checklist_tasks')",
    "'Add Checklist Task'": "TranslationHelper.translate('add_checklist_task')",
    "'No items. Add at least one task for supervisors.'": "TranslationHelper.translate('no_items_add_task')",
    "'Task #${index + 1}'": "TranslationHelper.translate('task_hash') + '${index + 1}'",
    "'e.g. Check for leakage'": "TranslationHelper.translate('eg_check_leakage')",
    "'SAVE CHANGES'": "TranslationHelper.translate('save_changes_caps')",
    "'CREATE POINT'": "TranslationHelper.translate('create_point')",
    
    # supervisor_list.dart & add_supervisor_screen.dart
    "'New Supervisor'": "TranslationHelper.translate('new_supervisor')",
    "'Edit Supervisor'": "TranslationHelper.translate('edit_supervisor')",
    "'Delete Supervisor'": "TranslationHelper.translate('delete_supervisor')",
    "'Loading supervisors...'": "TranslationHelper.translate('loading_supervisors')",
    "'No supervisors found'": "TranslationHelper.translate('no_supervisors')",
    "'Add New Supervisor'": "TranslationHelper.translate('add_new_supervisor')",
    "'Full Name'": "TranslationHelper.translate('full_name')",
    "'Phone Number'": "TranslationHelper.translate('phone_number')",
    "'Role'": "TranslationHelper.translate('role')",
    "'Create Account'": "TranslationHelper.translate('create_account')",
    "'Supervisor added successfully'": "TranslationHelper.translate('supervisor_added')",
}

for path in files:
    try:
        with open(path, 'r') as f:
            content = f.read()
        
        # Add import if not present
        if "TranslationHelper" in str(replacements) and 'translation_helper.dart' not in content:
            content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport '../../utils/translation_helper.dart';")
            content = content.replace("import 'package:provider/provider.dart';", "import 'package:provider/provider.dart';\nimport '../../utils/translation_helper.dart';")

        for k, v in replacements.items():
            content = content.replace(k, v)
            
        with open(path, 'w') as f:
            f.write(content)
        print("Processed " + path)
    except FileNotFoundError:
        print("Not found: " + path)
