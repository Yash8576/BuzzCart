import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../../../core/providers/add_product_provider.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  
  // Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    // Load state from provider
    final provider = context.read<AddProductProvider>();
    _titleController.text = provider.productName;
    _descriptionController.text = provider.description;
    _priceController.text = provider.price;
    _stockController.text = provider.stock;
    
    // Add listeners to update provider
    _titleController.addListener(() {
      provider.setProductName(_titleController.text);
    });
    _descriptionController.addListener(() {
      provider.setDescription(_descriptionController.text);
    });
    _priceController.addListener(() {
      provider.setPrice(_priceController.text);
    });
    _stockController.addListener(() {
      provider.setStock(_stockController.text);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final provider = context.read<AddProductProvider>();
    final mediaType = provider.selectedMediaType;
    
    try {
      if (mediaType == 'photo') {
        final List<XFile> images = await _picker.pickMultiImage(
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
        
        if (images.isNotEmpty) {
          for (var image in images) {
            if (provider.selectedFiles.length < 5) {
              provider.addFile(File(image.path));
            } else {
              break;
            }
          }
        }
      } else if (mediaType == 'video' || mediaType == 'reel') {
        final XFile? video = await _picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: mediaType == 'reel'
              ? const Duration(seconds: 60)
              : const Duration(minutes: 5),
        );
        
        if (video != null && provider.selectedFiles.length < 5) {
          provider.addFile(File(video.path));
        }
      } else if (mediaType == 'audio') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio upload coming soon!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking media: $e')),
      );
    }
  }

  Future<void> _submitProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = context.read<AddProductProvider>();
    
    if (provider.selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one product media file')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // TODO: Implement actual product creation
      // Example:
      // final response = await apiService.createProduct(
      //   title: provider.productName,
      //   description: provider.description,
      //   price: double.parse(provider.price),
      //   category: _categoryController.text,
      //   stock: int.parse(provider.stock),
      //   media: provider.selectedFiles,
      //   mediaType: provider.selectedMediaType,
      // );
      
      await Future.delayed(const Duration(seconds: 2)); // Simulated upload
      
      if (mounted) {
        provider.clearAll(); // Clear state after successful upload
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product created successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create product: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AddProductProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Add New Product'),
            actions: [
              if (!_isUploading)
                TextButton(
                  onPressed: _submitProduct,
                  child: const Text(
                    'Publish',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Product Media Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Product Media',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Media type selector
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.photo, size: 16),
                                      SizedBox(height: 2),
                                      Text('Photo', style: TextStyle(fontSize: 10)),
                                    ],
                                  ),
                                  selected: provider.selectedMediaType == 'photo',
                                  onSelected: (selected) {
                                    if (selected) {
                                      provider.setMediaType('photo');
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.videocam, size: 16),
                                      SizedBox(height: 2),
                                      Text('Video', style: TextStyle(fontSize: 10)),
                                    ],
                                  ),
                                  selected: provider.selectedMediaType == 'video',
                                  onSelected: (selected) {
                                    if (selected) {
                                      provider.setMediaType('video');
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.movie, size: 16),
                                      SizedBox(height: 2),
                                      Text('Reel', style: TextStyle(fontSize: 10)),
                                    ],
                                  ),
                                  selected: provider.selectedMediaType == 'reel',
                                  onSelected: (selected) {
                                    if (selected) {
                                      provider.setMediaType('reel');
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.audiotrack, size: 16),
                                      SizedBox(height: 2),
                                      Text('Audio', style: TextStyle(fontSize: 10)),
                                    ],
                                  ),
                                  selected: provider.selectedMediaType == 'audio',
                                  onSelected: (selected) {
                                    if (selected) {
                                      provider.setMediaType('audio');
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          Text(
                            'Add up to 5 ${provider.selectedMediaType == 'photo' ? 'images' : 'files'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Media grid
                          SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: provider.selectedFiles.length + 1,
                              itemBuilder: (context, index) {
                                if (index == provider.selectedFiles.length) {
                                  // Add button
                                  return GestureDetector(
                                    onTap: provider.selectedFiles.length < 5 ? _pickMedia : null,
                                    child: Container(
                                      width: 100,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            provider.selectedMediaType == 'photo' ? Icons.add_photo_alternate :
                                            provider.selectedMediaType == 'video' || provider.selectedMediaType == 'reel' ? Icons.video_library :
                                            Icons.audio_file,
                                            size: 32,
                                            color: provider.selectedFiles.length < 5
                                                ? Colors.blue
                                                : Colors.grey,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Add',
                                            style: TextStyle(
                                              color: provider.selectedFiles.length < 5
                                                  ? Colors.blue
                                                  : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                                
                                // Media preview
                                return Stack(
                                  children: [
                                    Container(
                                      width: 100,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: Colors.grey.shade200,
                                        image: provider.selectedMediaType == 'photo' ? DecorationImage(
                                          image: FileImage(provider.selectedFiles[index]),
                                          fit: BoxFit.cover,
                                        ) : null,
                                      ),
                                      child: provider.selectedMediaType != 'photo' ? Center(
                                        child: Icon(
                                          provider.selectedMediaType == 'video' || provider.selectedMediaType == 'reel' 
                                              ? Icons.play_circle_outline 
                                              : Icons.audiotrack,
                                          size: 40,
                                          color: Colors.blue,
                                        ),
                                      ) : null,
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 12,
                                      child: GestureDetector(
                                        onTap: () => provider.removeFile(index),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (index == 0)
                                      Positioned(
                                        bottom: 4,
                                        left: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'Main',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Product Title
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Product Name *',
                      hintText: 'Enter product name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter product name';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'Description *',
                      hintText: 'Describe your product...',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter product description';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Price and Stock Row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Price *',
                            hintText: '0.00',
                            prefixText: '\$ ',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter price';
                            }
                            final price = double.tryParse(value);
                            if (price == null || price <= 0) {
                              return 'Invalid price';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _stockController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Stock *',
                            hintText: '0',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter stock';
                            }
                            final stock = int.tryParse(value);
                            if (stock == null || stock < 0) {
                              return 'Invalid stock';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Category
                  TextFormField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Category *',
                      hintText: 'e.g., Electronics, Fashion, Home',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter category';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isUploading ? null : _submitProduct,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: _isUploading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Create Product',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
