import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';

/// App entrypoint. Sets up Provider(s) via `App` (see app.dart).
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Loads OPENAI_API_KEY (and any future secrets) from the bundled .env
  // asset — see spec.md §2-§3, milestone03. .env itself is gitignored;
  // .env.example documents the variable name.
  await dotenv.load(fileName: '.env');
  runApp(const App());
}
