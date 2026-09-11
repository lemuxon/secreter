import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../utils/app_theme.dart';
import '../../../messaging/presentation/screens/messaging_screen.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/di/injection.dart';
import '../../../group/data/datasources/group_remote_datasource.dart';

/// Global kanal arama + katılma. Tüm kanallar içinde isme göre arar
/// (büyük/küçük harf duyarsız, istemci tarafı filtre — index gerektirmez).
class ChannelSearchScreen extends StatefulWidget {
  final String myUid;
  const ChannelSearchScreen({super.key, required this.myUid});

  @override
  State<ChannelSearchScreen> createState() => _ChannelSearchScreenState();
}

class _ChannelSearchScreenState extends State<ChannelSearchScreen> {
  final _controller = TextEditingController();
  bool _searching = false;
  bool _searched = false;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _results = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _controller.text.trim().toLowerCase();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _searched = true;
    });
    try {
      // ⚠️ ARTIK `chats` DEĞİL, `channels` DİZİNİ SORGULANIYOR.
      //
      // Eskiden kanal arama tüm `chats` dokümanlarını çekiyordu; bu, üye
      // OLMAYAN birinin her kanalın ÜYE LİSTESİNİ, son mesajını ve
      // ayarlarını okuyabilmesi demekti. Güvenlik kuralı artık `chats`
      // listelemeyi yalnızca kendi sohbetlerine izin veriyor.
      //
      // `channels/{chatId}` yalnızca keşif için gereken KAMUYA AÇIK
      // alanları taşır (ad, açıklama, üye sayısı) ve tek yazıcısı
      // Cloud Function'dır (syncChannelDirectory).
      final snap = await FirebaseFirestore.instance
          .collection('channels')
          .orderBy('nameLower')
          .startAt([q])
          .endAt(['$q'])
          .limit(50)
          .get();

      var results = snap.docs;
      if (results.isEmpty) {
        // Önek eşleşmesi yoksa: geniş çekip istemcide "içeriyor" araması.
        final all = await FirebaseFirestore.instance
            .collection('channels')
            .orderBy('memberCount', descending: true)
            .limit(100)
            .get();
        results = all.docs
            .where((d) => (d.data()['nameLower'] ?? '').toString().contains(q))
            .toList();
      }
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('err_unexpected'))),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _joinAndOpen(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    final chatId = doc.id;
    final name = (data['name'] ?? data['groupName'] ?? 'Kanal').toString();

    // ⚠️ YASAK KONTROLÜ ARTIK SUNUCUDA.
    // Dizin dokümanı üye/yasaklı listesi TAŞIMAZ (taşısaydı bu listeler
    // yine herkese açık olurdu). Katılma denemesi doğrudan yapılır;
    // yasaklıysa güvenlik kuralı `permission-denied` ile reddeder.
    try {
      try {
        // Ad YAZILMAZ (§4o): kanal üyeliği yalnızca uid ile tutulur.
        //
        // ⚠️ ARTIK DOĞRUDAN FIRESTORE'A YAZILMIYOR (§4an).
        // Burada `arrayUnion` + `increment(1)` vardı ve zaten üye
        // olunan bir kanala dokunmak sayacı HER SEFERİNDE bir
        // artırıyordu — koddaki yorum bunu "kural gereği geçer" diye
        // normal sayıyordu. `addMemberToArray` işlem içinde çalışır,
        // zaten üyeyse hiç yazmaz ve `memberCount`u gerçek uzunluğa
        // yazar. Ayrıca üyelik yazan tek bir yol kalır — ekranın
        // koleksiyona kendi başına yazması, bu projede §4u'yu üreten
        // desendi.
        // ⚠️ OKUMASIZ KATILMA (§4bn).
        //
        // Eskiden `addMemberToArray` çağrılıyordu; o işlem içinde önce
        // `tx.get` yapar ve kural üye OLMAYANIN sohbet dokümanını
        // okumasına izin vermez. Sonuç: katılmak isteyen HERKES
        // `permission-denied` alıyor, ekran da bunu "yasaklandınız"
        // diye gösteriyordu. Kimse yasaklı değildi.
        await getIt<GroupRemoteDataSource>().joinChannel(chatId);
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          if (!mounted) return;
          // ⚠️ ARTIK "YASAKLISIN" DEMİYORUZ.
          //
          // Bu kodun iki meşru sebebi var ve istemci ikisini
          // AYIRT EDEMEZ: (a) gerçekten yasaklı olmak, (b) zaten üye
          // olmak — ikincisinde eklenen küme boş kalır ve
          // `isSelfJoin()` tutmaz. Kesin olmayan bir suçlama yerine
          // katılınamadığını söylüyoruz; ayrımı ancak sunucu yapabilir
          // (ileride katılma bir Cloud Function'a taşınırsa netleşir).
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('err_channel_join'))),
          );
          return;
        }
        rethrow;
      }
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MessagingScreen(
          chatId: chatId,
          chatTitle: name,
          myUid: widget.myUid,
          isGroup: true,
        ),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('join_failed'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(context.tr('search_channels_t'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: context.tr('channel_name_hint'),
                      hintStyle: const TextStyle(color: AppTheme.textSecondary),
                      prefixIcon: const Icon(Icons.search,
                          color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _searching ? null : _search,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: const Color(0xFF04141C),
                  ),
                  child: _searching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF04141C)),
                        )
                      : Text(context.tr('search')),
                ),
              ],
            ),
          ),
          Expanded(
            child: !_searched
                ? Center(
                    child: Text(context.tr('type_channel_search'),
                        style: const TextStyle(color: AppTheme.textSecondary)),
                  )
                : _results.isEmpty
                    ? Center(
                        child: Text(context.tr('channel_not_found'),
                            style:
                                const TextStyle(color: AppTheme.textSecondary)),
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final doc = _results[i];
                          final data = doc.data();
                          // Dizin şeması: {name, nameLower, description,
                          // memberCount, avatarUrl}
                          final name =
                              (data['name'] ?? data['groupName'] ?? 'Kanal')
                                  .toString();
                          final count = (data['memberCount'] ?? 0).toString();
                          final avatarUrl =
                              (data['avatarUrl'] ?? '').toString();
                          final isMember =
                              List<String>.from(data['memberIds'] ?? [])
                                  .contains(widget.myUid);
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primary,
                              backgroundImage: avatarUrl.isNotEmpty
                                  ? CachedNetworkImageProvider(avatarUrl)
                                  : null,
                              child: avatarUrl.isNotEmpty
                                  ? null
                                  : Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          color: Color(0xFF04141C),
                                          fontWeight: FontWeight.w700),
                                    ),
                            ),
                            title: Text(name,
                                style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text('$count abone',
                                style: const TextStyle(
                                    color: AppTheme.textSecondary)),
                            trailing: isMember
                                ? Text(context.tr('you_are_member'),
                                    style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12))
                                : const Icon(Icons.add_circle_outline,
                                    color: AppTheme.primary),
                            onTap: () => _joinAndOpen(doc),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
