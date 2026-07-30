# 手燈控制 MVP

用 Flutter + `flutter_blue_plus` 做的 GFRIEND 手燈 BLE 調色盤，協定是從實機封包逆向出來的：

```
01 01 0b 00 00 [R] [G] [B] 00 00 7e
```

## 使用前置作業

### 1. 建立 Flutter 專案骨架

這個資料夾只有 `pubspec.yaml` 和 `lib/main.dart`，其他 iOS/Android 專案檔要靠 Flutter CLI 產生：

```bash
flutter create --project-name lightstick_controller .
```

（在這個資料夾內執行，它會補齊 `ios/`、`android/` 等資料夾，`lib/main.dart` 跟 `pubspec.yaml` 保留你已經有的版本，不會覆蓋）

### 2. iOS 藍牙權限（一定要加，不加會直接 crash 或掃不到裝置）

打開 `ios/Runner/Info.plist`，加入：

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>需要藍牙權限以連接並控制手燈</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>需要藍牙權限以連接並控制手燈</string>
```

### 3. 麥克風權限（演唱會模式需要，一定要加）

同樣在 `ios/Runner/Info.plist` 加入：

```xml
<key>NSMicrophoneUsageDescription</key>
<string>需要麥克風權限以偵測現場音樂節奏來同步手燈</string>
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
</array>
```

`UIBackgroundModes` 這段是 `audio_streamer` 套件要求的（演唱會模式 v2 用它來讀取原始音訊做 FFT 分析），沒加的話收音可能會不穩定或中斷。

### 4. Android 權限

`flutter_blue_plus` 官方套件通常會自動處理 manifest merge，但如果掃描不到裝置，檢查 `android/app/src/main/AndroidManifest.xml` 是否有：

```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

### 4. 安裝套件並執行

```bash
flutter pub get
flutter run
```

## 運作邏輯

1. 開 App 自動開始掃描附近 BLE 裝置
2. 點選你的手燈裝置 → 自動連線 → 自動掃描所有 service/characteristic，找出支援 **Write Without Response** 的那一個（對應我們用 PacketLogger 抓到的 `Write Command 0x52`）
3. 進入**模式選擇畫面**，選擇要用哪個模式控制手燈

## 目前的檔案結構

```
lib/
  main.dart                        入口，只負責啟動 App
  ble/
    lightstick_service.dart        BLE 核心邏輯（連線、組封包、送出）
  screens/
    scan_screen.dart               掃描裝置畫面
    mode_select_screen.dart        模式選擇畫面
    custom_mode_screen.dart        自訂模式：圓盤調色 + 閃爍開關
    group_mode_screen.dart         團體模式：開發中佔位頁
    concert_mode_screen.dart       演唱會模式：麥克風收音節拍同步
```

## 三個模式的現況

**自訂模式** — 已可用。用 `flutter_colorpicker` 的 `HueRingPicker` 做圓盤調色，拖動即時送出換色封包。閃爍開關目前是**停用狀態**，因為閃爍指令的封包還沒抓過，UI 先做好等之後補協定。

**團體模式** — 純佔位頁，顯示「開發中」。

**演唱會模式** — v2：用 `audio_streamer` 拿到麥克風原始 PCM 波形，透過 `fftea` 做 FFT 頻率分析，算出即時音高與低頻能量。「自動選色」時色相隨音高連續變化（低音偏紅、高音偏藍紫，是自訂的映射方式，非科學上的聲光對應）；「手動選色」時從你勾選的顏色裡，每偵測到一次節拍就切換下一個。節拍偵測用低頻能量的移動平均加上可調靈敏度（畫面上有滑桿即時調整，不用重新建置），比單純音量門檻穩定。閃爍效果同樣是用已知的換色協定快速切換顏色/熄燈做出的「軟體閃爍」。

## 已知限制 / 之後可以做的事

- **自動偵測 characteristic** 目前是抓「第一個支援 writeWithoutResponse 的 characteristic」，如果手燈同時有多個這種 characteristic（例如電量或韌體更新用的），可能會抓錯。如果測試發現不準，把 `LightstickService.discoverWritableCharacteristic()` 改成用固定 UUID 比對（去 LightBlue 裡把該 characteristic 的完整 UUID 抄下來寫死）會更保險。
- 目前只做了「換色」，如果之後抓到閃爍、呼吸燈等模式的封包，可以在 `LightstickService` 裡加對應的 `buildXxxPacket()` 方法。
- 滑桿有做 60ms debounce 避免狂送封包，如果手燈反應會延遲或掉包，可以調整這個數值。
- 沒有做斷線重連、多裝置記憶等機制，MVP 先求能動。