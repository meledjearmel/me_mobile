import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_palette.dart';
import '../../../core/utils/relative_date.dart';
import '../../../shared/widgets/resource_list_scaffold.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/surfaces.dart';
import '../../dashboard/data/dashboard.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../profile/data/profile.dart';
import '../application/cv_download_list_controller.dart';
import '../data/cv_download.dart';
import '../data/cv_download_repository.dart';

/// Téléchargements du CV depuis le site, du plus récent au plus ancien :
/// synthèse (tableau de bord), recherche, filtre par langue, détail en feuille.
class CvDownloadsScreen extends ConsumerStatefulWidget {
  const CvDownloadsScreen({super.key});

  @override
  ConsumerState<CvDownloadsScreen> createState() => _CvDownloadsScreenState();
}

class _CvDownloadsScreenState extends ConsumerState<CvDownloadsScreen> {
  static const _locales = [null, 'fr', 'en'];

  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    // De nouveaux téléchargements ont pu arriver depuis la dernière ouverture.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.invalidate(cvDownloadListProvider);
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// `by_country` ne donne que le nom du pays (pas le code ISO) : on passe par
  /// la recherche, qui couvre aussi le pays.
  void _searchFor(String text) {
    _search.text = text;
    ref.read(cvDownloadListProvider.notifier).setSearch(text);
  }

  Future<void> _openDetail(CvDownload download) async {
    final deleted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _CvDownloadSheet(download: download),
    );
    if (deleted == true && mounted) {
      ref.read(cvDownloadListProvider.notifier).removeItem((d) => d.id == download.id);
      ref.invalidate(dashboardProvider);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Téléchargement supprimé')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cvDownloadListProvider);
    final notifier = ref.read(cvDownloadListProvider.notifier);
    final current = state.value?.query.filters['locale'] as String?;
    final summary = ref.watch(dashboardProvider).asData?.value.cvDownloads;

    return ResourceListScaffold<CvDownload>(
      title: 'CV téléchargés',
      searchHint: 'Email, ville, pays, campagne…',
      searchController: _search,
      header: summary == null || summary.total == 0 ? null : _SummaryCard(summary: summary, onSearch: _searchFor),
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: () async {
        ref.invalidate(dashboardProvider);
        await notifier.refresh();
      },
      onRetry: () => ref.invalidate(cvDownloadListProvider),
      filterChips: [
        for (final locale in _locales)
          PillFilterChip(
            label: locale == null ? 'Toutes' : locale.toUpperCase(),
            selected: current == locale,
            onTap: () => notifier.setFilters({'locale': locale}),
          ),
      ],
      emptyIcon: Icons.download_outlined,
      emptyTitle: 'Aucun téléchargement',
      emptyDescription: 'Les téléchargements du CV depuis le site apparaîtront ici.',
      itemBuilder: (context, item) => ListCardTile(
        leading: _FlagTile(countryCode: item.countryCode),
        title: item.place ?? 'Lieu inconnu',
        subtitle: [jobProfileText(item), item.locale.toUpperCase(), originText(item)].join(' · '),
        meta: item.createdAt == null ? null : relativeDate(item.createdAt!),
        badge: StatusBadge(sourceText(item.source)),
        onTap: () => _openDetail(item),
      ),
    );
  }
}

String jobProfileText(CvDownload download) => download.jobProfileLabel?.display ?? 'Profil supprimé';

String originText(CvDownload download) => download.origin == 'direct' ? 'Accès direct' : download.origin;

String sourceText(CvSource source) => source == CvSource.uploaded ? 'Importé' : 'Généré';

/// Drapeau emoji tiré du code ISO (`CI` → 🇨🇮), ou `null` s'il est invalide.
String? flagEmoji(String? countryCode) {
  final code = countryCode?.trim().toUpperCase() ?? '';
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(code)) {
    return null;
  }
  return String.fromCharCodes(code.codeUnits.map((c) => 0x1F1E6 + c - 0x41));
}

class _FlagTile extends StatelessWidget {
  const _FlagTile({required this.countryCode});

  final String? countryCode;

  @override
  Widget build(BuildContext context) {
    final flag = flagEmoji(countryCode);
    if (flag == null) {
      return const IconTile(Icons.public_rounded, size: 38);
    }
    return ExcludeSemantics(
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(38 * 0.34),
        ),
        child: Text(flag, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}

/// Synthèse du tableau de bord : trois chiffres, puis les premiers pays et
/// provenances en barres fines (toucher une ligne lance la recherche).
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.onSearch});

  final DashboardCvDownloads summary;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final countries = summary.byCountry.take(3).toList();
    final origins = summary.byOrigin.take(3).toList();

    return SurfaceCard(
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _Figure(value: summary.total, label: 'au total'),
              ),
              Expanded(
                child: _Figure(value: summary.period, label: 'sur ${summary.periodDays} j'),
              ),
              Expanded(
                child: _Figure(value: summary.withEmail, label: 'avec email'),
              ),
            ],
          ),
          if (countries.isNotEmpty || origins.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 10),
          ],
          if (countries.isNotEmpty) _BarGroup(title: 'Pays', items: countries, onTap: onSearch),
          if (countries.isNotEmpty && origins.isNotEmpty) const SizedBox(height: 8),
          if (origins.isNotEmpty)
            _BarGroup(
              title: 'Provenance',
              items: origins,
              // `direct` n'est pas un texte cherchable côté API.
              onTap: (label) {
                if (label != 'direct') {
                  onSearch(label);
                }
              },
              labelOf: (label) => label == 'direct' ? 'Accès direct' : label,
            ),
          if (countries.isNotEmpty || origins.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Sur ${summary.periodDays} jours · touchez une ligne pour filtrer',
                style: theme.textTheme.labelSmall?.copyWith(color: colors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: theme.textTheme.headlineSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: context.appColors.muted)),
      ],
    );
  }
}

class _BarGroup extends StatelessWidget {
  const _BarGroup({required this.title, required this.items, required this.onTap, this.labelOf});

  final String title;
  final List<CategoryCount> items;
  final ValueChanged<String> onTap;
  final String Function(String label)? labelOf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final max = items.map((i) => i.count).fold<int>(1, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelSmall?.copyWith(color: colors.muted, fontWeight: FontWeight.w700),
        ),
        for (final item in items)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onTap(item.label),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      labelOf?.call(item.label) ?? item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: item.count / max,
                        minHeight: 6,
                        backgroundColor: theme.colorScheme.surfaceContainerHigh,
                        valueColor: AlwaysStoppedAnimation(colors.accent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 28,
                    child: Text('${item.count}', textAlign: TextAlign.right, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Détail d'un téléchargement. Renvoie `true` après suppression.
class _CvDownloadSheet extends ConsumerStatefulWidget {
  const _CvDownloadSheet({required this.download});

  final CvDownload download;

  @override
  ConsumerState<_CvDownloadSheet> createState() => _CvDownloadSheetState();
}

class _CvDownloadSheetState extends ConsumerState<_CvDownloadSheet> {
  bool _deleting = false;

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce téléchargement ?'),
        content: const Text('Il disparaîtra aussi des statistiques.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _deleting = true);
    try {
      await ref.read(cvDownloadRepositoryProvider).delete(widget.download.id);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Suppression impossible, réessayez.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = widget.download;
    final campaign = [d.utmSource, d.utmMedium, d.utmCampaign].whereType<String>().where((s) => s.isNotEmpty);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _FlagTile(countryCode: d.countryCode),
                const SizedBox(width: 12),
                Expanded(child: Text(d.place ?? 'Lieu inconnu', style: theme.textTheme.titleLarge)),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.mail_outline_rounded,
              label: 'Email',
              value: d.email ?? 'Non renseigné',
              trailing: d.email == null
                  ? null
                  : IconButton(
                      tooltip: 'Écrire',
                      icon: const Icon(Icons.send_rounded),
                      onPressed: () => launchUrl(Uri.parse('mailto:${d.email}')),
                    ),
            ),
            _InfoRow(icon: Icons.badge_outlined, label: 'Profil métier', value: jobProfileText(d)),
            _InfoRow(
              icon: Icons.description_outlined,
              label: 'CV servi',
              value: '${d.locale.toUpperCase()} · ${d.source.label}',
            ),
            _InfoRow(icon: Icons.link_rounded, label: 'Site d\'origine', value: d.referrerHost ?? 'Accès direct'),
            if (campaign.isNotEmpty)
              _InfoRow(icon: Icons.campaign_outlined, label: 'Campagne', value: campaign.join(' · ')),
            _InfoRow(icon: Icons.devices_rounded, label: 'Appareil', value: d.device?.label ?? 'Inconnu'),
            if (d.createdAt != null)
              _InfoRow(icon: Icons.schedule_rounded, label: 'Date', value: fullDate(d.createdAt!.toLocal())),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _deleting ? null : _delete,
                style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                icon: _deleting
                    ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.delete_outline_rounded),
                label: const Text('Supprimer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value, this.trailing});

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.appColors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelSmall?.copyWith(color: context.appColors.muted)),
                Text(value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Carte pleine largeur des téléchargements du CV (Statistiques, accueil) :
/// gros chiffre de la période, total et emails laissés en légende.
class CvDownloadsCard extends StatelessWidget {
  const CvDownloadsCard({super.key, required this.summary, this.onTap});

  final DashboardCvDownloads summary;

  /// Ouvre la liste des téléchargements.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final topCountry = summary.byCountry.isEmpty ? null : summary.byCountry.first.label;

    return SurfaceCard(
      radius: 22,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sur ${summary.periodDays} jours',
                  style: theme.textTheme.bodySmall?.copyWith(color: colors.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  '${summary.period}',
                  style: theme.textTheme.headlineSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
                const SizedBox(height: 2),
                Text(
                  ['${summary.total} au total', '${summary.withEmail} avec email', ?topCountry].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: colors.muted, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ExcludeSemantics(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
              child: Icon(Icons.download_rounded, size: 30, color: colors.onAccent),
            ),
          ),
        ],
      ),
    );
  }
}
