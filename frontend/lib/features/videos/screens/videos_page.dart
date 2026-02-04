import 'package:flutter/material.dart';

class VideosPage extends StatelessWidget {
  final String? videoId;

  const VideosPage({super.key, this.videoId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Videos'),
      ),
      body: Center(
        child: Text(
          videoId != null 
              ? 'Video Player: $videoId' 
              : 'Videos Page - Coming Soon',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
