# 🍏 Yakınlık Radarı — iPhone (.ipa) Oluşturma ve Sideloadly ile Yükleme Rehberi

Apple (iOS) uygulamaları (`.ipa`) yalnızca macOS / Xcode derleyicisiyle paketlenebilir. Windows bilgisayarınızda ek bir Mac bilgisayara ihtiyaç duymadan **ücretsiz olarak `.ipa` dosyasını oluşturup** Sideloadly ile iPhone kullanan arkadaşlarınıza yüklemeniz için her şeyi bu klasörde hazır hale getirdik.

---

## Adım 1: Ücretsiz `.ipa` Dosyasını 2 Dakikada Üretme (GitHub Actions ile)
Bu klasörün içindeki `.github/workflows/build-ios-ipa.yml` dosyası, projeyi GitHub'a yüklediğiniz anda ücretsiz bir macOS sunucusu başlatıp **`YakinlikRadari_iOS.ipa`** dosyasını otomatik derler:

1. [github.com](https://github.com) üzerinde ücretsiz bir hesap açın ve **New Repository** diyerek boş bir proje oluşturun.
2. `c:\Users\oguzi\Desktop\Yeni klasör` içindeki **`ios_app`** ve **`.github`** klasörlerini GitHub'a yükleyin.
3. GitHub sayfasında üstteki **Actions** sekmesine tıklayın.
4. **"Build iOS IPA (Sideloadly)"** çalışmasını göreceksiniz (~1-2 dakika sürer).
5. Tamamlandığında altındaki **`YakinlikRadari_iOS_IPA`** bağlantısına tıklayarak içindeki **`YakinlikRadari_iOS.ipa`** dosyasını bilgisayarınıza indirin.
   - Artık bu `.ipa` dosyasını WhatsApp veya Telegram üzerinden iPhone kullanan arkadaşlarınıza gönderebilirsiniz!

---

## Adım 2: Sideloadly İle iPhone'a Yükleme (Arkadaşlarınız İçin)
1. Bilgisayara ücretsiz **[Sideloadly](https://sideloadly.io/)** programını indirip kurun (Ayrıca bilgisayarda iTunes / iCloud kurulu olmalıdır).
2. iPhone'u USB kabloyla bilgisayara bağlayın ve iPhone ekranında çıkan **"Bu Bilgisayara Güven"** uyarısına izin verin.
3. **Sideloadly** programını açın:
   - Sol üstteki **IPA** kutusuna `YakinlikRadari_iOS.ipa` dosyasını sürükleyip bırakın.
   - **Apple ID** kutusuna iPhone sahibinin kendi Apple e-posta adresini yazın.
   - **Start** butonuna basın (İlk seferde Apple şifresi ve telefona gelen 6 haneli doğrulama kodunu soracaktır).
4. İşlem "Done" dediğinde uygulama iPhone ana ekranına gelir.

---

## Adım 3: iPhone'da Uygulamaya Güvenme (Tek Seferlik)
Uygulamayı ilk kez açmadan önce iPhone'da şu adımı yapın:
1. **Ayarlar > Genel > VPN ve Aygıt Yönetimi** menüsüne girin.
2. **Geliştirici Uygulaması** altında kendi Apple ID adresinize dokunun ve **"Güven (Trust)"** seçeneğine basın.
3. ArtıkiPhone'da **Ayarlar > Gizlilik ve Güvenlik > Geliştirici Modu**'nu (iOS 16 ve üzeri için) açıp uygulamayı doğrudan kullanabilirsiniz!
