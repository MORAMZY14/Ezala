# MMR Cabinets

تطبيق Flutter عربي حديث لمتابعة خزائن MMR وصناديقها. يحتوي على تسجيل
الدخول وإنشاء الحساب، لوحة ملخصات، بحث وفلاتر، وتحديث مباشر لحالة كل صندوق
بين قيد الانتظار ومؤكد.

## لماذا Firestore وليس Storage فقط؟

- Cloud Firestore هو مصدر بيانات التطبيق، لأنه يدعم الاستعلام والتصفية
  والاستماع للتحديثات لحظيًا.
- Firebase Storage يحتفظ بنسخة أصلية من ملف Excel لأغراض الأرشفة.
- Firebase Authentication يدير تسجيل الدخول وإنشاء الحسابات.

البيانات المرفقة جاهزة داخل assets/data/mmr_cabinets.json:

- 17 خزانة
- 1,046 صندوق
- 711 مؤكد
- 335 قيد الانتظار

نسخة ملف Excel الأصلي موجودة في
source/Copy_of_Cross_Connection_MMR.xlsx للرجوع إليها.

الخلايا الفارغة اعتبرت قيد الانتظار. القيمة Cast 7-9 في A-3 / BOX 13
حفظت كملاحظة، والخطأ الإملائي دخلى طبع إلى داخلي.

## التشغيل لأول مرة على Windows

المشروع يحتوي على كود التطبيق. أنشئ مجلدات Android وiOS وWeb الناقصة من
داخل مجلد المشروع:

    flutter create . --org com.mmr --project-name mmr_cabinets_app --platforms=android,ios,web
    flutter pub get

ثبت أدوات Firebase إذا لم تكن مثبتة:

    npm install -g firebase-tools
    dart pub global activate flutterfire_cli
    firebase login

أنشئ مشروعًا من Firebase Console، ثم فعّل:

1. Authentication ثم Sign-in method ثم Email/Password.
2. Cloud Firestore.
3. Cloud Storage.

بعد ذلك اربط المنصات:

    flutterfire configure
    firebase use --add
    firebase deploy --only firestore:rules,storage

ثم شغّل:

    flutter run

ملف lib/firebase_options.dart المرفق مجرد Placeholder صالح للبناء. أمر
flutterfire configure يستبدله تلقائيًا بقيم مشروعك الحقيقية.

## أول استيراد

1. أنشئ أول حساب من شاشة التسجيل.
2. افتح زر استيراد Excel من أعلى لوحة الخزائن.
3. اختر تحميل بيانات البداية لاستيراد الملف المرفق مباشرة.
4. لاحقًا يمكنك اختيار أي ملف xlsx بنفس البناء.

كل Sheet يمثل خزانة مثل A-1 أو B-2. الصف الأول عنوان، والصف الثاني أسماء
الأعمدة، وتبدأ الصناديق من الصف الثالث:

1. Box NO
2. داخلي أو خارجي
3. موقف الاستلام

## بنية Firestore

    users/{uid}
    cabinets/{cabinetId}
    cabinets/{cabinetId}/boxes/{boxId}
    imports/{importId}

تحديث الحالة يتم داخل Transaction حتى تبقى أعداد مؤكد وقيد الانتظار في
الخزانة صحيحة. الاستيراد يقسم الكتابات إلى دفعات أقل من حد Firestore.

## الحماية الحالية

القواعد تسمح لأي مستخدم مسجل بقراءة الخزائن وتعديل الحالات واستيراد ملف.
وهي مناسبة لتطبيق فريق داخلي. قبل فتح التسجيل للعامة، أضف نظام موافقة
للحسابات أو Custom Claims للأدوار وفعّل Firebase App Check.

## فحص المشروع

    flutter analyze
    flutter test
    node tools/validate_seed.mjs
