import 'package:chisa/util/anki_creator.dart';
import 'package:chisa/util/export_paths.dart';
import 'package:chisa/util/return_from_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chisa/models/app_model.dart';
import 'package:chisa/pages/home_page.dart';
import 'package:uni_links/uni_links.dart';
import 'package:wakelock/wakelock.dart';

/// Application execution starts here.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Wakelock.disable();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await Permission.manageExternalStorage.request();
  requestAnkiDroidPermissions();

  initialiseExportPaths();

  SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
  PackageInfo packageInfo = await PackageInfo.fromPlatform();

  runApp(
    App(
      sharedPreferences: sharedPreferences,
      packageInfo: packageInfo,
    ),
  );
}

Future<void> initUniLinks() async {
  // Platform messages may fail, so we use a try/catch PlatformException.
  try {
    final String? initialLink = await getInitialLink();
    // Parse the link and warn the user, if it is not correct,
    // but keep in mind it could be `null`.
  } on PlatformException {
    // Handle exception by warning the user their action did not succeed
    // return?
  }
}

class App extends StatelessWidget {
  const App({
    Key? key,
    required this.sharedPreferences,
    required this.packageInfo,
  }) : super(key: key);

  final SharedPreferences sharedPreferences;
  final PackageInfo packageInfo;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppModel>(
      create: (_) => AppModel(
        sharedPreferences: sharedPreferences,
        packageInfo: packageInfo,
      ),
      child: Consumer<AppModel>(
        builder: (_, appModel, __) {
          return MaterialApp(
            locale: appModel.getLocale(),
            debugShowCheckedModeBanner: false,
            theme: appModel.getLightTheme(context),
            darkTheme: appModel.getDarkTheme(context),
            themeMode:
                appModel.getIsDarkMode() ? ThemeMode.dark : ThemeMode.light,
            home: blankWhileUninitialised(appModel),
          );
        },
      ),
    );
  }

  Widget blankWhileUninitialised(AppModel appModel) {
    if (appModel.hasInitialized) {
      return homeOrDeepLink();
    } else {
      return FutureBuilder(
        future: appModel.initialiseAppModel(),
        builder: (BuildContext context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container();
          } else {
            return homeOrDeepLink();
          }
        },
      );
    }
  }

  Widget homeOrDeepLink() {
    bool initialLinkProcessed = false;

    return Scaffold(
      body: StreamBuilder<String?>(
          stream: linkStream,
          builder: (context, streamSnapshot) {
            final link = streamSnapshot.data ?? '';
            if (link.isNotEmpty) {
              returnFromAppLink(context, link);
              return const HomePage();
            }

            return FutureBuilder<String?>(
                future: getInitialLink(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final link = snapshot.data ?? '';

                  if (link.isNotEmpty && !initialLinkProcessed) {
                    initialLinkProcessed = true;
                    returnFromAppLink(context, link);
                  }

                  return const HomePage();
                });
          }),
    );
  }
}
