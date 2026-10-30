/// Paste your Supabase project details here.
/// Project Settings > API: the Project URL and the anon / publishable key.
/// NEVER paste the service_role (secret) key into the app.
const String kSupabaseUrl = 'https://mqjtjsyyrgpnfkytbjpo.supabase.co';
const String kSupabaseAnonKey = 'sb_publishable_fonohIw-mAYR997Rw6TaUw_I7JG6tAf';
/// False until both values above are filled in. The app then keeps running
/// in prototype mode (no server).
bool get kSupabaseReady =>
    kSupabaseUrl.startsWith('https://') &&
    kSupabaseAnonKey.length > 20 &&
    !kSupabaseAnonKey.startsWith('PASTE');