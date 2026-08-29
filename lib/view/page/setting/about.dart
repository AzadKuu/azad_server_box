part of 'entry.dart';

final class _AppAboutPage extends StatefulWidget {
  const _AppAboutPage();

  @override
  State<_AppAboutPage> createState() => _AppAboutPageState();
}

final class _AppAboutPageState extends State<_AppAboutPage>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(13),
        children: [
          UIs.height13,
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 47, maxWidth: 47),
            child: UIs.appIcon,
          ),
          const Text(
            '${BuildData.name}\nv${BuildData.build}',
            textAlign: TextAlign.center,
            style: UIs.text15,
          ),
          UIs.height13,
          SimpleMarkdown(
            data:
                '''
#### ${l10n.menuGitHubRepository}
[${Urls.thisRepo}](${Urls.thisRepo})

#### Upstream
[${Urls.upstreamRepo}](${Urls.upstreamRepo})
''',
          ).paddingAll(13).cardx,
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
