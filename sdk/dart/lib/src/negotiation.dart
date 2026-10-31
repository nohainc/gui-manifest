import 'package:nanomarkup/nanomarkup.dart';

import 'model.dart';

/// Result of inspecting process arguments for `--gui-manifest`.
sealed class GuiManifestRequest {
  const GuiManifestRequest();

  /// Returns null when [args] is not a manifest request.
  ///
  /// A request is exactly one argument: `--gui-manifest` (version 1) or
  /// `--gui-manifest=N`.
  static GuiManifestRequest? parse(List<String> args) {
    if (args.length != 1) return null;
    final arg = args.single;
    if (arg == '--gui-manifest') return const GuiManifestAccepted(1);
    if (!arg.startsWith('--gui-manifest=')) return null;
    final raw = arg.substring('--gui-manifest='.length);
    final requested = RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(raw)
        ? int.parse(raw)
        : null;
    if (requested == null) {
      return GuiManifestRejected('invalid manifest version "$raw"');
    }
    final usable = supportedManifestVersions.where((v) => v <= requested);
    if (usable.isEmpty) {
      return GuiManifestRejected(
        'manifest version $requested is not supported; '
        'supported: ${supportedManifestVersions.join(', ')}',
      );
    }
    return GuiManifestAccepted(usable.reduce((a, b) => a > b ? a : b));
  }
}

final class GuiManifestAccepted extends GuiManifestRequest {
  const GuiManifestAccepted(this.version);

  /// Version to produce: the highest supported one not above the request.
  final int version;
}

final class GuiManifestRejected extends GuiManifestRequest {
  const GuiManifestRejected(this.message);

  final String message;
}

/// Encodes [manifest] as a Nano Markup document.
String encodeManifest(GuiManifest manifest) => encode(manifest.toTree());
