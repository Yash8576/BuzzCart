import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class UploadContentScreen extends StatefulWidget {
  const UploadContentScreen({super.key});

  @override
  State<UploadContentScreen> createState() => _UploadContentScreenState();
}

class _UploadContentScreenState extends State<UploadContentScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _captionController = TextEditingController();
  List<XFile> _selectedFiles = [];
  String _contentType = 'image'; // 'image' or 'video'
  bool _isUploading = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(ImageSource source) async {
    try {
      if (_contentType == 'image') {
        final XFile? image = await _picker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
        if (image != null) {
          setState(() {
            _selectedFiles = [image];
          });
        }
      } else {
        final XFile? video = await _picker.pickVideo(
          source: source,
          maxDuration: const Duration(minutes: 2),
        );
        if (video != null) {
          setState(() {
            _selectedFiles = [video];
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking media: $e')),
      );
    }
  }

  Future<void> _uploadContent() async {
    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file to upload')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // TODO: Implement actual upload to backend
      // Example:
      // final response = await apiService.uploadContent(
      //   file: _selectedFiles.first,
      //   caption: _captionController.text,
      //   type: _contentType,
      // );
      
      await Future.delayed(const Duration(seconds: 2)); // Simulated upload
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Content uploaded successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Content'),
        actions: [
          if (_selectedFiles.isNotEmpty && !_isUploading)
            TextButton(
              onPressed: _uploadContent,
              child: const Text(
                'Upload',
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Content type selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Content Type',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image, size: 20),
                                SizedBox(width: 8),
                                Text('Image'),
                              ],
                            ),
                            selected: _contentType == 'image',
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _contentType = 'image';
                                  _selectedFiles = [];
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.videocam, size: 20),
                                SizedBox(width: 8),
                                Text('Video'),
                              ],
                            ),
                            selected: _contentType == 'video',
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _contentType = 'video';
                                  _selectedFiles = [];
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Preview area
            if (_selectedFiles.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Preview',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _selectedFiles = [];
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _contentType == 'image'
                            ? Image.file(
                                File(_selectedFiles.first.path),
                                fit: BoxFit.cover,
                                height: 200,
                                width: double.infinity,
                              )
                            : Container(
                                height: 200,
                                color: Colors.black,
                                child: const Center(
                                  child: Icon(
                                    Icons.play_circle_outline,
                                    size: 64,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedFiles.first.name,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              )
            else
              // Upload buttons
              Column(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickMedia(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: Text(
                      _contentType == 'image'
                          ? 'Choose from Gallery'
                          : 'Choose Video',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _pickMedia(ImageSource.camera),
                    icon: Icon(
                      _contentType == 'image' ? Icons.camera_alt : Icons.videocam,
                    ),
                    label: Text(
                      _contentType == 'image'
                          ? 'Take Photo'
                          : 'Record Video',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 20),

            // Caption input
            TextField(
              controller: _captionController,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Caption (Optional)',
                hintText: 'Write a caption for your post...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 20),

            // Upload button (main)
            if (_selectedFiles.isNotEmpty)
              ElevatedButton(
                onPressed: _isUploading ? null : _uploadContent,
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
                        'Upload Content',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
