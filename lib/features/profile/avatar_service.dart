import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Why the user cannot get a picture right now, in words worth showing them.
enum AvatarFailure {
  /// The picker was opened and closed without choosing anything. Not an error.
  cancelled,

  /// The system refused access. iOS shows its own prompt for this, so the app
  /// only explains what to do next and never draws a fake dialog.
  denied,

  /// The file could not be read or copied.
  unreadable,
}

class AvatarException implements Exception {
  const AvatarException(this.failure, [this.message]);

  final AvatarFailure failure;
  final String? message;

  String get description => switch (failure) {
    AvatarFailure.cancelled => 'No photo chosen.',
    AvatarFailure.denied =>
      'Cluckfall Heights has no access to that yet. You can grant it in the '
          'Settings app, under Cluckfall Heights.',
    AvatarFailure.unreadable => 'That image could not be read. Try another one.',
  };
}

/// Gets a profile photo from the camera or the photo library and keeps a copy
/// inside the app's own documents folder.
///
/// The copy matters: the picker hands back a path in a system cache that is free
/// to disappear, which would leave the profile showing a broken image later. The
/// image is also asked for at a modest size, since it is only ever drawn as a
/// small circle and there is no reason to store megabytes for that.
///
/// Nothing is uploaded anywhere. There is no network code in this app at all.
class AvatarService {
  AvatarService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static const int _maxEdge = 900;

  Future<String> capture() => _pick(ImageSource.camera);

  Future<String> choose() => _pick(ImageSource.gallery);

  Future<String> _pick(ImageSource source) async {
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: source,
        maxWidth: _maxEdge.toDouble(),
        maxHeight: _maxEdge.toDouble(),
        imageQuality: 88,
        preferredCameraDevice: CameraDevice.front,
      );
    } on Exception catch (error) {
      throw AvatarException(AvatarFailure.denied, error.toString());
    }

    if (file == null) throw const AvatarException(AvatarFailure.cancelled);

    try {
      final Directory documents = await getApplicationDocumentsDirectory();
      final Directory folder = Directory('${documents.path}/profile');
      if (!folder.existsSync()) folder.createSync(recursive: true);

      final String extension = file.path.split('.').last.toLowerCase();
      final String target =
          '${folder.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.'
          '${extension.length <= 4 ? extension : 'jpg'}';

      await File(file.path).copy(target);
      return target;
    } on FileSystemException catch (error) {
      throw AvatarException(AvatarFailure.unreadable, error.message);
    }
  }

  /// Deletes the stored copy. Failure is ignored on purpose: the profile has
  /// already stopped pointing at the file, and a leftover file is not worth
  /// interrupting the user over.
  Future<void> discard(String? path) async {
    if (path == null) return;
    try {
      final File file = File(path);
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      return;
    }
  }
}

final Provider<AvatarService> avatarServiceProvider = Provider<AvatarService>(
  (ref) => AvatarService(),
);
