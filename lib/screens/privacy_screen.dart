import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: kUltraViolet)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(fontSize: 14, height: 1.7)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('隱私權說明')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('簡單來說',
                '這個 App 不會建立帳號、不會蒐集個人資料、不會把任何資料傳到伺服器，也沒有第三方廣告或分析工具。App 用到的權限只是為了讓功能能正常運作。'),
            _section('藍牙權限',
                '用來掃描、連接你的手燈裝置，並傳送控制指令（換色、閃爍）。僅用於跟你自己的手燈裝置通訊，不會用來追蹤位置，也不會蒐集或上傳附近其他藍牙裝置的資訊。'),
            _section('麥克風權限',
                '僅在「演唱會模式」啟用時使用。App 會即時分析麥克風收到的聲音頻率（音高、節奏），用來即時決定手燈顯示效果。所有分析都在裝置上即時完成，不會被錄製、儲存或上傳，也不會辨識歌曲或對話內容。關閉該模式即停止使用。'),
            _section('我們不會做的事',
                '不會要求註冊或登入、不會蒐集姓名/Email/位置等個人資料、不會將資料傳輸或儲存到外部伺服器、不會使用第三方分析或廣告 SDK、不會將資料出售或分享給第三方。'),
            _section('兒童隱私', '本 App 不會刻意向 13 歲以下兒童蒐集個人資料，且本身也不具備蒐集個人資料的功能。'),
            _section('政策異動', '若未來新增需要蒐集資料的功能，本頁面會同步更新。最後更新日期：2026 年 8 月。'),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse('mailto:ben920601@gmail.com?subject=隱私權問題'),
                ),
                icon: const Icon(Icons.mail_outline),
                label: const Text('有隱私權相關問題，聯絡我'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
