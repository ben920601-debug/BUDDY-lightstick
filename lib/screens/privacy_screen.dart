import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../widgets/gradient_app_bar.dart';

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
      appBar: const GradientAppBar(title: '隱私權說明'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('簡單來說',
                '這個 App 不需要註冊帳號，也不會蒐集你的姓名、Email 等個人資料，沒有第三方廣告或分析工具。App 會連線到我們自己維護的伺服器，僅用於取得公告內容、功能開關狀態，以及讓「粉絲聊天室」功能運作。'),
            _section('伺服器連線',
                '開啟 App 時，會向我們的伺服器查詢目前的公告內容與各功能是否開放（例如維護中）。這個步驟不會傳送任何跟你有關的個人資訊。'),
            _section('粉絲聊天室',
                '使用聊天室時，App 會在你的手機上自動產生一組匿名的裝置代碼（不是帳號、無法回推你的身份），聊天內容會連同這組代碼儲存在我們的伺服器上，用於讓你跟開發者能持續對話。這組代碼只存在你自己的手機裡，換手機或刪除重裝 App 就會產生新的一組，歷史對話不會被找回。你可以在聊天室右上角檢舉不當內容，開發者會據此處理（包含封鎖）。'),
            _section('藍牙權限',
                '用來掃描、連接你的手燈裝置，並傳送控制指令（換色、閃爍）。僅用於跟你自己的手燈裝置通訊，不會用來追蹤位置，也不會蒐集或上傳附近其他藍牙裝置的資訊，這部分完全不經過我們的伺服器。'),
            _section('麥克風權限',
                '僅在「演唱會模式」啟用時使用。App 會即時分析麥克風收到的聲音頻率（音高、節奏），用來即時決定手燈顯示效果。所有分析都在裝置上即時完成，不會被錄製、儲存或上傳到任何地方，也不會辨識歌曲或對話內容。關閉該模式即停止使用。'),
            _section('我們不會做的事',
                '不會要求註冊或登入、不會蒐集姓名/Email/位置等個人資料、不會使用第三方分析或廣告 SDK、不會將資料出售或分享給第三方、不會將聊天內容用於除了回覆你以外的其他用途。'),
            _section('兒童隱私', '本 App 不會刻意向 13 歲以下兒童蒐集個人資料。'),
            _section('政策異動', '若未來功能有變動導致資料蒐集方式改變，本頁面會同步更新。最後更新日期：2026 年 8 月。'),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse('mailto:your-email@example.com?subject=隱私權問題'),
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
