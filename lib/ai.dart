import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'main.dart';

const String kAiUrl = 'https://rlpfwpvdcvofcirmbkom.supabase.co/functions/v1/quran-ai';

class AiTab extends StatefulWidget {
  const AiTab({super.key});
  @override
  State<AiTab> createState() => _AiTabState();
}

class _AiTabState extends State<AiTab> {
  final msgs = <Map<String, String>>[];
  final ctrl = TextEditingController();
  final scroll = ScrollController();
  bool busy = false;

  Future<void> send(String text) async {
    final q = text.trim();
    if (q.isEmpty || busy) return;
    ctrl.clear();
    setState(() { msgs.add({'role': 'user', 'content': q}); busy = true; });
    _down();
    String answer;
    try {
      final hist = msgs.length > 1 ? msgs.sublist(0, msgs.length - 1) : <Map<String, String>>[];
      final r = await http
          .post(Uri.parse(kAiUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'question': q, 'history': hist}))
          .timeout(const Duration(seconds: 40));
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      answer = r.statusCode == 200 ? (j['answer'] ?? 'لا توجد إجابة') : (j['error'] ?? 'حدث خطأ، حاول لاحقًا');
    } catch (_) {
      answer = 'تعذّر الاتصال. تأكد من الإنترنت وحاول مرة أخرى.';
    }
    if (mounted) setState(() { msgs.add({'role': 'assistant', 'content': answer}); busy = false; });
    _down();
  }

  void _down() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent + 200, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  static const samples = ['ما فضل سورة الكهف؟', 'اشرح لي معنى آية الكرسي', 'ما الفرق بين المكي والمدني؟', 'كيف أحافظ على أذكار الصباح؟'];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('اسأل عن القرآن', style: TextStyle(fontWeight: FontWeight.bold))),
        body: Column(children: [
          Expanded(
            child: msgs.isEmpty
                ? ListView(padding: const EdgeInsets.all(16), children: [
                    const Icon(Icons.auto_awesome, color: gold, size: 56),
                    const SizedBox(height: 12),
                    const Text('مساعد ذكي مجاني للأسئلة العامة عن القرآن والأذكار. قد يخطئ الذكاء الاصطناعي: لا تعتمد عليه في الأحكام والأحاديث، وارجع للمصادر وأهل العلم.', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    for (final s in samples) Card(child: ListTile(title: Text(s), trailing: const Icon(Icons.north_west, color: gold), onTap: () => send(s))),
                  ])
                : ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: msgs.length + (busy ? 1 : 0),
                    itemBuilder: (c, i) {
                      if (i == msgs.length) return const Padding(padding: EdgeInsets.all(12), child: Align(alignment: Alignment.centerRight, child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: gold))));
                      final m = msgs[i];
                      final me = m['role'] == 'user';
                      return Align(
                        alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(c).size.width * .85),
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: me ? gold.withValues(alpha: .22) : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: gold.withValues(alpha: .5), width: .6)),
                          child: SelectableText(m['content']!, style: const TextStyle(fontSize: 16, height: 1.7)),
                        ),
                      );
                    }),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
              child: Row(children: [
                Expanded(child: TextField(controller: ctrl, minLines: 1, maxLines: 4, textInputAction: TextInputAction.send, onSubmitted: send, decoration: InputDecoration(hintText: 'اكتب سؤالك', border: OutlineInputBorder(borderRadius: BorderRadius.circular(22)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)))),
                IconButton(icon: const Icon(Icons.send, color: gold), onPressed: busy ? null : () => send(ctrl.text)),
              ]),
            ),
          ),
        ]),
      );
}
