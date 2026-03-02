import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show XFile;

class UploadContentProvider extends ChangeNotifier {
  String _selectedMediaType = 'photo';
  final List<XFile> _selectedFiles = [];
  String _caption = '';
  String _visibility = 'public'; // 'public', 'followers', 'close_friends'
  bool _hasUnsavedWork = false;
  VoidCallback? _onUploadSuccess;
  String _photoAspectRatio = 'square'; // 'square', 'portrait', 'landscape'

  String get selectedMediaType => _selectedMediaType;
  List<XFile> get selectedFiles => List.unmodifiable(_selectedFiles);
  String get caption => _caption;
  String get visibility => _visibility;
  bool get hasUnsavedWork => _hasUnsavedWork;
  String get photoAspectRatio => _photoAspectRatio;

  void setOnUploadSuccess(VoidCallback? callback) {
    _onUploadSuccess = callback;
  }

  void notifyUploadSuccess() {
    _onUploadSuccess?.call();
    notifyListeners();
  }

  void setMediaType(String type) {
    _selectedMediaType = type;
    _hasUnsavedWork = true;
    notifyListeners();
  }

  void setPhotoAspectRatio(String ratio) {
    _photoAspectRatio = ratio;
    _hasUnsavedWork = true;
    notifyListeners();
  }

  void addFile(XFile file) {
    _selectedFiles.add(file);
    _hasUnsavedWork = true;
    notifyListeners();
  }

  void removeFile(int index) {
    if (index >= 0 && index < _selectedFiles.length) {
      _selectedFiles.removeAt(index);
      _hasUnsavedWork = _selectedFiles.isNotEmpty || _caption.isNotEmpty;
      notifyListeners();
    }
  }

  void setCaption(String text) {
    _caption = text;
    _hasUnsavedWork = text.isNotEmpty || _selectedFiles.isNotEmpty;
    notifyListeners();
  }

  void setVisibility(String visibility) {
    _visibility = visibility;
    _hasUnsavedWork = true;
    notifyListeners();
  }

  void clearAll() {
    _selectedMediaType = 'photo';
    _selectedFiles.clear();
    _caption = '';
    _visibility = 'public';
    _photoAspectRatio = 'square';
    _hasUnsavedWork = false;
    notifyListeners();
  }

  void markAsSaved() {
    _hasUnsavedWork = false;
    notifyListeners();
  }
}
