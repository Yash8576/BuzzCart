import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../../../core/providers/upload_content_provider.dart';

class UploadContentScreen extends StatefulWidget {
  const UploadContentScreen({super.key});

  @override
  State<UploadContentScreen> createState() => _UploadContentScreenState();
}

class _UploadContentScreenState extends State<UploadContentScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _captionController = TextEditingController();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    // Load state from provider
    final provider = context.read<UploadContentProvider>();
    _captionController.text = provider.caption;
    _captionController.addListener(() {
      provider.setCaption(_captionController.text);
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(ImageSource source) async {
    final provider = context.read<UploadContentProvider>();
    final contentType = provider.selectedMediaType;
    
    try {
      if (contentType == 'photo') {
        final XFile? image = await _picker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
        if (image != null) {
          provider.addFile(File(image.path));
        }
      } else if (contentType == 'video' || contentType == 'reel') {
        final XFile? video = await _picker.pickVideo(
          source: source,
          maxDuration: contentType == 'reel' 
              ? const Duration(seconds: 60) 
              : const Duration(minutes: 10),
        );
        if (video != null) {
          provider.addFile(File(video.path));
        }
      } else if (contentType == 'audio') {
        // For audio, we'll use a file picker or let user record
        // For now, showing a message
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

  Future<void> _uploadContent() async {
    final provider = context.read<UploadContentProvider>();
    
    if (provider.selectedFiles.isEmpty) {
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
      //   file: provider.selectedFiles.first,
      //   caption: provider.caption,
      //   type: provider.selectedMediaType,
      // );
      
      await Future.delayed(const Duration(seconds: 2)); // Simulated upload
      
      if (mounted) {
        provider.clearAll(); // Clear state after successful upload
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
    return Consumer<UploadContentProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Upload Content'),
            actions: [
              if (provider.selectedFiles.isNotEmpty && !_isUploading)
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
                                label: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.photo, size: 20),
                                    SizedBox(height: 4),
                                    Text('Photo', style: TextStyle(fontSize: 11)),
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
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.videocam, size: 20),
                                    SizedBox(height: 4),
                                    Text('Video', style: TextStyle(fontSize: 11)),
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
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.movie, size: 20),
                                    SizedBox(height: 4),
                                    Text('Reel', style: TextStyle(fontSize: 11)),
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
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.audiotrack, size: 20),
                                    SizedBox(height: 4),
                                    Text('Audio', style: TextStyle(fontSize: 11)),
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
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Preview area
                if (provider.selectedFiles.isNotEmpty)
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
                                  provider.removeFile(0);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: provider.selectedMediaType == 'photo'
                                ? Image.file(
                                    provider.selectedFiles.first,
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
                            provider.selectedFiles.first.path.split('/').last,
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
                          provider.selectedMediaType == 'photo'
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
                          provider.selectedMediaType == 'photo' ? Icons.camera_alt : Icons.videocam,
                        ),
                        label: Text(
                          provider.selectedMediaType == 'photo'
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
                if (provider.selectedFiles.isNotEmpty)
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
      },
    );
  }
}
