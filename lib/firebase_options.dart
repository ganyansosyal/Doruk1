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
  apiKey: 'AIzaSyAY1EZw5Z4SIh0aEKVG6QrzQPhfsFhKKhA',
  appId: '1:871686667838:web:1fe9b89ff588869fc69b6f',
  messagingSenderId: '871686667838',
  projectId: 'ganyansosyal',
  storageBucket: 'ganyansosyal.firebasestorage.app',
);

bool firebaseReady = false;
String firebaseProblem = '';

Future<void> initFirebase() async {
  if (firebaseOptions.apiKey.isEmpty) {
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
