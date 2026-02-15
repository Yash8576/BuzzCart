import 'dart:io';
import 'package:flutter/foundation.dart';

class UploadContentProvider extends ChangeNotifier {
  String _selectedMediaType = 'photo';
  final List<File> _selectedFiles = [];
  String _caption = '';
  String _visibility = 'public'; // 'public', 'followers', 'close_friends'
  bool _hasUnsavedWork = false;
  VoidCallback? _onUploadSuccess;

  String get selectedMediaType => _selectedMediaType;
  List<File> get selectedFiles => List.unmodifiable(_selectedFiles);
  String get caption => _caption;
  String get visibility => _visibility;
  bool get hasUnsavedWork => _hasUnsavedWork;

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

  void addFile(File file) {
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
    _hasUnsavedWork = false;
    notifyListeners();
  }

  void markAsSaved() {
    _hasUnsavedWork = false;
    notifyListeners();
  }
}
