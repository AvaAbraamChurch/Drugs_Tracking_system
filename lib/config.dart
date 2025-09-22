class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // GitHub repository settings for version checking
  static const String githubUsername = 'AvaAbraamChurch'; // Replace with your GitHub username
  static const String repositoryName = 'Drugs_Tracking_system'; // Your repository name
}