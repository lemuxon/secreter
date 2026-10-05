# Test fontu — Roboto Regular

`security_banners_test.dart` kırpılmayı **gerçek font metrikleriyle** ölçer.
Widget testinde varsayılan yedek font her glifi 1em genişlikte çizer;
Roboto'da Latin harfler yaklaşık yarısı kadardır. Yedek fontla ölçmek
"kırpılıyor" diye **yanlış alarm** verir — ölçüldü, altı bandın altısı da
düşüyordu.

## Neden depoda duruyor

Font önce Flutter SDK'sının önbelleğinden okunuyordu:

```
$FLUTTER_ROOT/bin/cache/artifacts/material_fonts/roboto-regular.ttf
```

Bu yol **temiz bir kurulumda boştur** — `flutter pub get` material
fontlarını indirmez. CI'da tam bu yüzden düştü (#2, #3, #4) ve
`flutter precache --universal` da doldurmadı. Ayrıca SDK'nın iç önbellek
düzeni Flutter sürümleri arasında değişebilir; teste temel yapılacak bir
sözleşme değil.

Fontu depoya koymak testi **hermetik** yapar: her makinede, her CI'da,
her Flutter sürümünde aynı şekilde çalışır.

## Lisans

Roboto — Apache License 2.0. Tam metin: `LICENSE-Roboto.txt`.
Projenin kendi lisansı (AGPL-3.0) bundan ayrıdır ve Apache-2.0 bir
varlığı bu şekilde barındırmak uyumludur.
