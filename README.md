# Ezla Project

تطبيق Flutter عربي لإدارة الكبائن والبوكسات مع Firebase. يدعم تسجيل الدخول،
الوضع الفاتح والداكن، طلب تغيير حالة البوكس، موافقة المسؤول، وسجل نشاط لحظي
يعرض اسم صاحب الطلب واسم المسؤول الذي وافق أو رفض.

## طريقة عمل الموافقات

1. يختار المستخدم «طلب تأكيد» أو «طلب تعليق» للبوكس.
2. تُحفظ العملية كطلب معلق، ولا تتغير حالة البوكس بعد.
3. يظهر الطلب فورًا في شاشة «النشاط المباشر» عند المسؤولين.
4. يوافق المسؤول أو يرفض الطلب.
5. عند الموافقة فقط، تُحدث حالة البوكس وأرقام الملخص داخل Transaction واحدة.
6. يسجل التطبيق الطلب والقرار والأسماء والتوقيت في Firestore لحظيًا.

## بنية Firestore

    users/{uid}
    cabinets/{cabinetId}
    cabinets/{cabinetId}/boxes/{boxId}
    statusRequests/{cabinetId__boxId}
    statusActivities/{activityId}
    imports/{importId}

كل حساب جديد يحصل تلقائيًا على:

    role: operator

ولإنشاء أول مسؤول:

1. أنشئ الحساب بصورة عادية داخل التطبيق.
2. افتح Firebase Console ثم Firestore Database ثم users.
3. افتح مستند المستخدم المطابق للـ UID.
4. غيّر الحقل role من operator إلى admin.

سيظهر وضع المسؤول في التطبيق مباشرة، مع أزرار الموافقة والرفض والاستيراد.
لا تسمح القواعد للمستخدم العادي بترقية نفسه إلى مسؤول.

## تطبيق قواعد Firebase المطلوبة

من مجلد المشروع في PowerShell:

    firebase use el-ezala
    firebase deploy --only firestore:rules,storage

نشر ملف firestore.rules ضروري. القواعد القديمة التي تحتوي على
`allow read, write: if false` ستمنع التسجيل والنشاط والموافقات.

## التشغيل بعد استبدال الملفات

    flutter clean
    flutter pub get
    flutter run

أضيفت حزمة shared_preferences لحفظ اختيار الوضع الداكن أو الفاتح على الجهاز.

## اسم التطبيق

اسم الواجهة داخل Flutter أصبح Ezla Project. إذا كانت مجلدات المنصات موجودة
لديك، شغل أداة PowerShell المرفقة مرة واحدة لتحديث الاسم تحت الأيقونة وفي
Web وiOS وWindows أيضًا:

    powershell -ExecutionPolicy Bypass -File tools/set_app_display_name.ps1

تغيير الاسم الظاهر لا يغير Android applicationId أو iOS bundle identifier
ولا يقطع اتصال Firebase.

## استيراد Excel

الاستيراد متاح للمسؤول فقط. Cloud Firestore هو مصدر البيانات الحية، بينما
Firebase Storage يحتفظ بنسخة Excel الأصلية عند رفع ملف جديد.

البيانات المرفقة داخل assets/data/mmr_cabinets.json:

- 17 كابينة
- 1,046 بوكس
- 711 مؤكد
- 335 قيد الانتظار

كل Sheet يمثل كابينة مثل A-1 أو B-2. الصف الأول عنوان، والصف الثاني أسماء
الأعمدة، وتبدأ البوكسات من الصف الثالث.

## الفحص

    flutter analyze
    flutter test
    node tools/validate_seed.mjs
    node tools/check_dart_structure.mjs
