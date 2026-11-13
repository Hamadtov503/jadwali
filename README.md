# جدولي

تطبيق آيفون (SwiftUI) للجدول الدراسي بعرضين: اليوم والأسبوع، وبثلاثة ألوان: الأخضر والبرتقالي والأزرق.

## التثبيت (TrollStore — مثل تطبيق مواعيدي)

كل `push` على `main` يبني التطبيق تلقائيًا في GitHub Actions، وينشره في إصدار اسمه **`latest`**.
افتح صفحة الإصدارات من الجوال، ثم اضغط `Jadwali.ipa`، ثم **Open in TrollStore**.

## البنية

```
.
├─ project.yml        ← XcodeGen
├─ Sources/
│  ├─ App/            ← JadwaliApp
│  ├─ Model/          ← ClassItem، Formatters
│  ├─ Services/       ← Store
│  └─ Views/          ← Root، Day، Week، Editor، Theme
└─ Resources/         ← الأيقونة والألوان
```

تُحفظ البيانات في `Application Support/classes.json` على الجوال. أقل إصدار مدعوم هو iOS 15.
