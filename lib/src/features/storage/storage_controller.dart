import '../../core/models/storage_models.dart';

class StorageController {
  const StorageController();

  int totalBytes(List<SdFileEntry> files) => files.fold(0, (sum, file) => sum + file.size);

  String parentPath(String path) {
    if (path == '/') return '/';
    final index = path.lastIndexOf('/');
    return index <= 0 ? '/' : path.substring(0, index);
  }
}
