package com.meledjearmel.me

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (et non FlutterActivity) : requis par local_auth,
// qui affiche l'invite biométrique via un DialogFragment androidx.
class MainActivity : FlutterFragmentActivity()
