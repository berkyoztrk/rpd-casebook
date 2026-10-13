# RPD Casebook — kurulum paketi

Bu paket, FiveM roleplay için ortak dedektif/soruşturma kayıt panelidir. Kullanıcı kayıt ve giriş sistemi Supabase Auth, ortak veri tabanı Supabase Postgres, yayın ise Vercel ile çalışır.

## Özellikler
- E-posta ve şifreyle kayıt/giriş
- Yeni üyeler otomatik olarak **onay bekliyor** durumuna alınır
- Admin üye onaylar ve Viewer / Detective / Admin rolünü belirler
- Onaylı üyeler soruşturma, delil, ifade, zaman çizelgesi ve raporları görüntüler
- Detective ve Admin kayıt ekler, düzenler ve siler
- RLS politikaları veritabanında uygulanır; sadece arayüzde gizleme değildir
- Vercel'de statik yayın yapılabilir; veriler herkesin tarayıcısında değil ortak Supabase veritabanında tutulur

> Bu sistem FiveM rol yapma içindir. Gerçek kişilerin özel bilgilerini, gerçek polis kayıtlarını, gerçek soruşturma dosyalarını veya hassas kişisel verileri yüklemeyin.

## 1. Supabase projesi oluştur
1. https://supabase.com adresine gir ve ücretsiz hesap aç.
2. **New project** seç. Proje adı belirle, güçlü bir veritabanı parolası oluştur ve bölge seç.
3. Proje açılınca sol menüden **SQL Editor** bölümüne gir.
4. Bu paketteki `schema.sql` dosyasını bilgisayarında aç, içindeki her şeyi kopyalayıp SQL Editor'e yapıştır ve **Run** de.
5. SQL tamamlandıktan sonra **Project Settings / API** veya **Connect** ekranından **Project URL** ile **Publishable key** bilgilerini bul. Eski projelerde publishable key yerine `anon` key görünebilir.
6. **Secret key veya service_role key'i web sitesine asla yapıştırma.** Tarayıcıya sadece publishable/anon key konur; veri güvenliğini SQL içindeki RLS kuralları sağlar.

## 2. İlk admin hesabını oluştur
1. Web sitesi yayınlandıktan sonra kendin için kayıt oluştur.
2. Supabase panelinde **Authentication → Users** sayfasını aç, kendi kullanıcı kaydını bul ve UUID / User ID değerini kopyala.
3. **SQL Editor** bölümünde şu komutu çalıştır. UUID bölümünü kendi kullanıcı ID'nle değiştir:

```sql
update public.profiles
set approved = true, role = 'admin'
where id = 'BURAYA-KENDI-USER-UUID-DEGERINI-YAZ';
```

4. Siteye dön, çıkış yapıp tekrar giriş yap. Artık **Üye Onayları** menüsünü görebilirsin. Yeni kayıt olanların hesaplarını burada onayla ve rollerini seç.

### E-posta doğrulaması hakkında
Supabase Auth ayarlarında e-posta doğrulaması açıksa kayıt olan kişinin e-postasını doğrulaması gerekir. Gerçek kullanıcılar için doğrulamayı açık tutman daha güvenlidir; e-posta gönderimi/SMTP ayarlarını Supabase Auth ayarlarından düzenleyebilirsin. Test için kapatmak mümkündür ama herkese açık kullanımda önerilmez.

## 3. Vercel'de ücretsiz yayınla
1. https://vercel.com adresine gir ve hesap aç.
2. Bu ZIP'i bilgisayarına indirip bir klasöre çıkar. İçindeki `index.html`, `schema.sql` ve `README.md` aynı klasörde kalabilir.
3. En kolay yöntem: Vercel panelinde **Add New → Project** veya Dashboard'da **Deploy** akışını aç. GitHub ile yayınlayacaksan klasörü GitHub deposuna yükle ve Vercel'de **Import Project** ile o depoyu seç.
4. Bu paket statik bir HTML uygulamasıdır; framework seçmek gerekirse **Other** seç veya framework preset kullanmadan dağıt.
5. Build command ve output directory isteyen arayüzde build command boş bırakılabilir; output directory olarak `.` (proje kökü) kullanılır. Vercel arayüzü değişirse statik site / zero-configuration dağıtım yolunu seç.
6. **Deploy** düğmesine bas. Yayın tamamlanınca `https://proje-adin.vercel.app` benzeri bir adres oluşur. Bu bağlantıyı ekibine gönder.

Alternatif kolay yol, bir GitHub deposu oluşturup bu üç dosyayı yüklemek ve Vercel'de o depoyu import etmektir. Dosyada değişiklik yaptığında GitHub'a yeni sürümü gönderirsen Vercel yeniden deploy eder.

## 4. İlk bağlantıyı yap
1. Vercel bağlantını aç.
2. İlk kurulum ekranında Supabase **Project URL** ve **Publishable/anon key** bilgilerini gir.
3. **Bağlan ve devam et** de. Ayarlar o tarayıcıda localStorage'da saklanır; ekipteki her kişi ilk girişinde aynı iki proje bilgisini bir kez girer.
4. Giriş yap veya kayıt ol. Kayıt sonrası admin onayı gereklidir.

> URL ve publishable key gizli anahtar değildir ve istemci uygulamalarında kullanılmak üzere tasarlanır. Buna rağmen veritabanı tablolarındaki RLS politikalarını kaldırma. `service_role` / `secret` anahtarını hiçbir zaman `index.html`, Vercel frontend ayarları veya Discord'a koyma.

## 5. Roller
- **Viewer:** Onaylı ortak kayıtları okur.
- **Detective:** Okur, ekler, düzenler ve siler.
- **Admin:** Detective yetkilerine ek olarak üye onaylar, rol değiştirir ve profilleri yönetir.

Yeni kayıtlar varsayılan olarak onaysız `viewer` olur. Kullanıcı kendisi rolünü yükseltemez; rol yönetimi yalnızca admin policy ile yapılır.

## Sorun giderme
- **“Profil okunamadı” veya veri yüklenemiyor:** `schema.sql` dosyasının tamamının doğru Supabase projesinde çalıştığını kontrol et; URL ve key'in aynı projeye ait olduğundan emin ol.
- **Kayıt oldum ama içeri giremiyorum:** Bu beklenen durumdur; admin onayı gerekir. E-posta doğrulaması açıksa e-postanı da doğrula.
- **İlk admin menüsü yok:** SQL Editor'de yukarıdaki `update public.profiles ...` sorgusunu doğru UUID ile çalıştır ve tekrar giriş yap.
- **Diğer ekip üyesi kayıtları göremiyor:** Hesabının onaylandığını ve aynı Supabase URL/key ile bağlandığını kontrol et.
- **Vercel'de sayfa açılmıyor:** `index.html` dosyasının proje kökünde olduğundan ve statik dağıtım yapıldığından emin ol.

## Kaynaklar
- Supabase Auth: https://supabase.com/docs/guides/auth
- Row Level Security: https://supabase.com/docs/guides/database/postgres/row-level-security
- Supabase güvenli veri kullanımı: https://supabase.com/docs/guides/database/secure-data
- Vercel: https://vercel.com/docs
