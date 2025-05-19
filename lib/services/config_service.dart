
class ConfigService {
  static Future<void> initialize() async {
    // No need to load .env for web
  }

  static String get(String key) {
    return '';
  }


  // Firebase Web Config
  static String get firebaseWebApiKey => "AIzaSyDBbLQdcUGNo9MxpVqIxICuuOMRRkeyDGg";
  static String get firebaseWebAppId => "1:866184039578:web:1160ec2ab352c16f2fa323";
  static String get firebaseWebMessagingSenderId => "866184039578";
  static String get firebaseWebProjectId => "flutteross";
  static String get firebaseWebAuthDomain => "flutteross.firebaseapp.com";
  static String get firebaseWebStorageBucket => "flutteross.firebasestorage.app";

  // Firebase Android Config
  static String get firebaseAndroidApiKey => "AIzaSyCtSE6Wdt1sHoizCJiiyV1Nf0Z7VGa6xSY";
  static String get firebaseAndroidAppId => "1:866184039578:android:1d98bc9a8f4295782fa323";
  static String get firebaseAndroidMessagingSenderId => "866184039578";
  static String get firebaseAndroidProjectId => "flutteross";
  static String get firebaseAndroidStorageBucket => "flutteross.firebasestorage.app";

  // Firebase iOS Config
  static String get firebaseIosApiKey => '';
  static String get firebaseIosAppId => '';
  static String get firebaseIosMessagingSenderId => '';
  static String get firebaseIosProjectId => '';
  static String get firebaseIosStorageBucket => '';
  static String get firebaseIosClientId => '';
  static String get firebaseIosBundleId => '';

  // Stripe Config
  static String get stripePublishableKey => '';
  static String get stripeSecretKey => '';
}