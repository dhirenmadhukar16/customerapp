import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CompanyBlogScreen extends StatelessWidget {
  const CompanyBlogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Generate a long text list to simulate ~10,000 words
    final paragraph = """
WhiteFox was born out of a simple idea: that doing laundry shouldn't be a chore, but a seamless experience that gives you back your time. Our journey started in a small facility where we realized the potential of combining eco-friendly cleaning methods with modern technology. We believe in sustainability, quality, and community. Every garment that comes through our doors is treated with the utmost care, utilizing state-of-the-art machinery that minimizes water waste and carbon footprint. We continuously train our staff in the latest fabric care techniques so that even the most delicate silks and robust denims get exactly what they need.

Our vision extends beyond just cleaning clothes. We aim to revolutionize the lifestyle of our customers. Imagine a world where you never have to worry about sorting, washing, drying, or folding again. That's the world WhiteFox is building. Through our intuitive app, customers can schedule pickups, track their orders in real-time, and customize their washing preferences down to the type of detergent used. Our logistics network is optimized for efficiency, ensuring that your clothes are picked up and delivered right on time, every time.

We are proud to say that all our operations are 100% carbon-neutral. We've partnered with local environmental organizations to plant trees for every ton of laundry processed. Furthermore, our packaging is entirely biodegradable. The 'Fox' in WhiteFox represents our agility, intelligence, and commitment to the natural world. We navigate the complexities of urban logistics with the cunning of a fox, always finding the best route and the most efficient way to serve you.
""";

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300.0,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.primary,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Our Story & Vision',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://images.unsplash.com/photo-1545173168-9f1947eebb7f?q=80&w=1000&auto=format&fit=crop',
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7)
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24.0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index % 5 == 0 && index != 0) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          'https://images.unsplash.com/photo-1582735689369-4fe89db7114c?q=80&w=1000&auto=format&fit=crop',
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Text(
                      paragraph,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: AppTheme.darkText,
                      ),
                      textAlign: TextAlign.justify,
                    ),
                  );
                },
                // 50 blocks of text to simulate 10k words
                childCount: 50,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
