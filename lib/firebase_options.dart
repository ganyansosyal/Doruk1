import 'package:firebase_core/firebase_core.dart';

// Firebase konsolu > Proje ayarları > Uygulamalarım > Android uygulaması
// (paket adı: com.ganyansosyal.ganyansosyal_native) değerlerini buraya yaz.
// google-services.json içindeki karşılıkları:
//   apiKey            -> client[0].api_key[0].current_key
//   appId             -> client[0].client_info.mobilesdk_app_id
//   messagingSenderId -> project_info.project_number
//   projectId         -> project_info.project_id
//   storageBucket     -> project_info.storage_bucket
const firebaseOptions = FirebaseOptions(
  apiKey: 'BURAYA',
  appId: 'BURAYA',
  messagingSenderId: 'BURAYA',
  projectId: 'BURAYA',
  storageBucket: 'BURAYA',
);

bool firebaseReady = false;
String firebaseProblem = '';

Future<void> initFirebase() async {
  if (firebaseOptions.apiKey == 'BURAYA') {
    firebaseProblem = 'Firebase ayarları girilmemiş. lib/firebase_options.dart dosyasını doldur.';
    return;
  }
  try {
    await Firebase.initializeApp(options: firebaseOptions);
    firebaseReady = true;
  } catch (e) {
    firebaseProblem = 'Firebase başlatılamadı: $e';
  }
}
