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

### 3. Android 權限

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
3. 進入調色盤畫面，拖動 RGB 滑桿或點預設色塊，會即時送出封包給手燈

## 已知限制 / 之後可以做的事

- **自動偵測 characteristic** 目前是抓「第一個支援 writeWithoutResponse 的 characteristic」，如果手燈同時有多個這種 characteristic（例如電量或韌體更新用的），可能會抓錯。如果測試發現不準，把 `LightstickService.discoverWritableCharacteristic()` 改成用固定 UUID 比對（去 LightBlue 裡把該 characteristic 的完整 UUID 抄下來寫死）會更保險。
- 目前只做了「換色」，如果之後抓到閃爍、呼吸燈等模式的封包，可以在 `LightstickService` 裡加對應的 `buildXxxPacket()` 方法。
- 滑桿有做 60ms debounce 避免狂送封包，如果手燈反應會延遲或掉包，可以調整這個數值。
- 沒有做斷線重連、多裝置記憶等機制，MVP 先求能動。
