import 'package:omni_bridge/core/data/interfaces/resettable.dart';
import '../../domain/entities/support_link.dart';

abstract class ISupportLocalDataSource {
  Future<List<SupportLink>> getSupportLinks();
}

class SupportLocalDataSourceImpl implements ISupportLocalDataSource, IResettable {
  @override
  Future<List<SupportLink>> getSupportLinks() async {
    return const [
      SupportLink(
        title: 'User Guide',
        description: 'Learn how to use Omni Bridge for real-time translation.',
        url: 'https://github.com/Marshal-GG/omni-bridge-translator/wiki',
        icon: 'guide',
      ),
      SupportLink(
        title: 'FAQs',
        description: 'Find answers to common questions about the app.',
        url: 'https://github.com/Marshal-GG/omni-bridge-translator/wiki/FAQ',
        icon: 'faq',
      ),
      SupportLink(
        title: 'Community Discord',
        description: 'Join our community for tips and announcements.',
        url: 'https://discord.gg/example',
        icon: 'discord',
      ),
      SupportLink(
        title: 'Twitter / X',
        description: 'Follow us for the latest updates and news.',
        url: 'https://twitter.com/omni_bridge',
        icon: 'twitter',
      ),
    ];
  }

  @override
  void reset() {
    // No state to reset currently, but interface implementation is required
    // for future local caching of support tickets.
  }
}
