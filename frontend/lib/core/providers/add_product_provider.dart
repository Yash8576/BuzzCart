import 'dart:io';
import 'package:flutter/foundation.dart';

class AddProductProvider extends ChangeNotifier {
  String _selectedMediaType = 'photo';
  final List<File> _selectedFiles = [];
  String _productName = '';
  String _description = '';
  String _price = '';
  String _stock = '';
  bool _hasUnsavedWork = false;

  String get selectedMediaType => _selectedMediaType;
  List<File> get selectedFiles => List.unmodifiable(_selectedFiles);
  String get productName => _productName;
  String get description => _description;
  String get price => _price;
  String get stock => _stock;
  bool get hasUnsavedWork => _hasUnsavedWork;

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
      _updateUnsavedStatus();
      notifyListeners();
    }
  }

  void setProductName(String name) {
    _productName = name;
    _updateUnsavedStatus();
    notifyListeners();
  }

  void setDescription(String desc) {
    _description = desc;
    _updateUnsavedStatus();
    notifyListeners();
  }

  void setPrice(String priceValue) {
    _price = priceValue;
    _updateUnsavedStatus();
    notifyListeners();
  }

  void setStock(String stockValue) {
    _stock = stockValue;
    _updateUnsavedStatus();
    notifyListeners();
  }

  void _updateUnsavedStatus() {
    _hasUnsavedWork = _selectedFiles.isNotEmpty ||
        _productName.isNotEmpty ||
        _description.isNotEmpty ||
        _price.isNotEmpty ||
        _stock.isNotEmpty;
  }

  void clearAll() {
    _selectedMediaType = 'photo';
    _selectedFiles.clear();
    _productName = '';
    _description = '';
    _price = '';
    _stock = '';
    _hasUnsavedWork = false;
    notifyListeners();
  }

  void markAsSaved() {
    _hasUnsavedWork = false;
    notifyListeners();
  }
}
