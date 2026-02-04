import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buzz Social Cart'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) {
          return _ContentCard(index: index);
        },
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  final int index;

  const _ContentCard({required this.index});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Creator Info
          ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.electricBlue,
              child: Text(
                'U${index + 1}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text('Creator ${index + 1}'),
            subtitle: const Text('2 hours ago'),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {},
            ),
          ),
          
          // Content Image/Video Placeholder
          Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.electricBlue.withAlpha(77),
                  AppColors.neonPurple.withAlpha(77),
                ],
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    index % 2 == 0 ? Icons.play_circle_outline : Icons.image_outlined,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.shopping_bag, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          '3 Products',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.favorite_outline),
                  onPressed: () {},
                ),
                const Text('1.2K'),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.comment_outlined),
                  onPressed: () {},
                ),
                const Text('234'),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () {},
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.shopping_cart, size: 18),
                  label: const Text('Shop Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.electricBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Caption
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Amazing product showcase! Check out these trending items 🔥',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '#fashion #trending #shopping',
                  style: TextStyle(
                    color: AppColors.electricBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
