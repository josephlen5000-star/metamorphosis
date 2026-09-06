import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import '../widgets/barcode_scanner_sheet.dart';

sealed class BarcodeScanOutcome {
  const BarcodeScanOutcome();
}

class BarcodeScanCancelled extends BarcodeScanOutcome {
  const BarcodeScanCancelled();
}

class BarcodeScanUnavailable extends BarcodeScanOutcome {
  const BarcodeScanUnavailable();
}

class BarcodeScanPermissionDenied extends BarcodeScanOutcome {
  const BarcodeScanPermissionDenied();
}

class BarcodeScanned extends BarcodeScanOutcome {
  const BarcodeScanned(this.code);

  final String code;
}

typedef BarcodeScanner = Future<BarcodeScanOutcome> Function(
  BuildContext context,
);

bool get barcodeScanningSupported {
  if (kIsWeb) return true;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return true;
    default:
      return false;
  }
}

Future<BarcodeScanOutcome> scanBarcode(BuildContext context) async {
  if (!barcodeScanningSupported) {
    return const BarcodeScanUnavailable();
  }

  final result = await showCupertinoModalPopup<BarcodeScanOutcome>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const BarcodeScannerSheet(),
  );
  return result ?? const BarcodeScanCancelled();
}
