import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/eat/data/egyptian_food_pack.dart';
import 'package:own_hub/features/eat/domain/meal_sentence_parser.dart';
import 'package:own_hub/features/eat/presentation/eat_sample_library.dart';
import 'package:own_hub/l10n/app_l10n.dart';

const phrases = [
 'two eggs and a piece of bread','2 eggs','4 eggs','6 eggs','1 egg','egg','eggs','koshari','a koshari','koshary and a salad','grilled chicken with rice','half a chicken breast','200 g rice','200 grams of rice','a cup of milk','a glass of juice','tea with sugar and milk','three dates','a banana and an apple','one orange','ful and taameya and eggs','I had cereal and stuff','ads','lentils','potato','potatoes','rice','chicken','cheese','juice','milk','bread','salad',
 'بيضتين وعيش','اتنين بيض','تلات بيضات','أربع بيضات','خمس حبات','نص رغيف عيش','ربع كيلو لحمة','طبق كشري','كشري كبير','كشري صغير','فول وطعمية وسلطة','فول بالزيت','ساندوتش فول','ملوخية بالفراخ','ملوخية مع أرز','رز وفراخ مشوية','كوباية شاي بلبن','كوباية عصير مانجو','كوب لبن','٣ بيضات','٢ عيش','3 بيضات','ثلاثة عيش','كُشَرِي','فُول','كشرى','أرز','ارز','رز','عيش بلدي','عيش فينو','جبنة رومي','جبنة دومياطي','لبنة','حواوشي','كفتة','ممبار','فتة','محشي كرنب','بطاطس محمرة','بطاطس مسلوقة','وعيش','و عيش','بيض وعيش','بيض وفول','2 eggs و عيش','2 beid w 3eesh','koshari w roz','فطار: فول','غدا رز وفراخ','','   ','.','mmm','اه','أه كده','uh, um','sushi','pad thai','سوشي','999 eggs','١٠٠٠٠ عيش','1e9 rice','-3 eggs','0 eggs','2.5 eggs','٢,٥ بيض','كـشـري','3','٣','2 eggs and 2 eggs','عدس','بطاطس','جبنة','عصير','200 جرام رز','كوب لبن','2 spoons sugar','١٠٠ جرام فراخ',
];
void main(){
 setUpAll(()=>EgyptianFoodPack.adopt(File('assets/content/foods_eg.json').readAsStringSync()));
 for (final loc in const [Locale('en'),Locale('ar')]) {
  test('probe ${loc.languageCode}', () async {
   final l=await AppL10n.delegate.load(loc);
   final p=MealSentenceParser(eatSampleLibrary(l));
   final out=StringBuffer();
   for(final s in phrases){
     final r=p.parse(s);
     out.writeln('${loc.languageCode}\t"$s"\t${r.items.map((i)=>'${i.food.foodId}|size=${i.size.id}|x${i.servings}|${i.kcal}kcal').join(' ; ')}\tUNRES=${r.unresolved.map((u)=>u.text).toList()}');
   }
   File('/private/tmp/claude-501/-Users-mahmoudreda-ownhub/8888c062-f816-485c-b02b-7edede6cbc09/scratchpad/probe_${loc.languageCode}.txt').writeAsStringSync(out.toString());
  });
 }
}
