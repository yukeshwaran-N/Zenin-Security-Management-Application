import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://rndgqheinwvkbheppmyi.supabase.co',
    'sb_publishable_HUml26vDTq0SWfZFItnN4g_uxVR0U5z',
  );

  print('Fetching a checkpoint to check keys...');

  try {
    final response = await supabase.from('checkpoints').select().limit(1).single();
    print('Checkpoint keys: ${response.keys.toList()}');
    print('Checkpoint sample data: $response');
  } catch (e) {
    print('Error: $e');
  }
}
