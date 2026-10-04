# RAYNODesk — چیدمان معکوس ID، حذف سه‌نقطه، اندازهٔ ۴۰۰×۴۰۰، کادر فیروزه‌ای

دور قبلی پیاده‌سازی و منتشر شد (`cb4e79f00`، ریلیز `RAYNODesk-1.5.0-x86-5`). کاربر برنامهٔ ساخته‌شده را دیده و چهار ایراد گزارش کرده. **عکس پیوست قابل خواندن نبود** (این مدل ورودی تصویر ندارد)؛ تصمیم‌ها از روی توضیح متنی کاربر گرفته شده و در ادامه آمده.

## هدف نهایی

```
┌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┐   کادر 2px فیروزه‌ای #2DD4BF
┆ ID 123 456 789   شناسه ┆
└╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘
   چپ                    راست
```

- پنجره: دقیقاً ۴۰۰×۴۰۰
- آیکون سه‌نقطه: حذف
- برچسب «شناسه»: بدون آیکون، بدون کلیک، سمت راست
- منوی تنظیمات: فقط با `Ctrl+Alt+S`

## تصمیم‌های قطعی

| مورد | تصمیم |
|---|---|
| ترتیب ردیف | `ID` + شماره چپ، «شناسه» راست (کاملاً برعکس تصمیم قبلی) |
| سه‌نقطه | حذف کامل |
| دسترسی تنظیمات | فقط `Ctrl+Alt+S`؛ عمداً هیچ دکمهٔ قابل‌کلیکی نمی‌ماند |
| رنگ کادر | `#2DD4BF`، ضخامت `2px`، `border-radius: 4px` |
| اندازهٔ پنجره | حذف `scaleIt()` از هر ۴ نقطهٔ `index.tis` |

---

## ۱) حذف `scaleIt` از اندازهٔ پنجره

`scaleIt()` (`src/ui/common.tis:28`) در `scaleFactor` ضرب می‌کند و `scaleFactor` روی ویندوز برابر نسبت DPI است. اگر واحد `windowMinSize` در اسکیتر DIP باشد، این ضریب دوباره اعمال می‌شود و پنجره بزرگ‌تر از ۴۰۰×۴۰۰ می‌شود — همان چیزی که کاربر می‌بیند.

**`src/ui/index.tis:26-28`**
```tis
// html min-width, min-height not working on mac, below works for all
view.windowMinSize = (scaleIt(window_width), scaleIt(window_height));
view.windowMaxSize = (scaleIt(window_width), scaleIt(window_height));
```
→
```tis
// html min-width, min-height not working on mac, below works for all
view.windowMinSize = (window_width, window_height);
view.windowMaxSize = (window_width, window_height);
```

**`src/ui/index.tis:61-67`** — `get_msgbox_width` هم باید هم‌تراز شود، وگرنه popupها از پنجرهٔ کوچک‌تر بیرون می‌زنند:
```tis
        var maxw = scaleIt(incoming_only_width);
```
→
```tis
        var maxw = incoming_only_width;
```

**`src/ui/index.tis:1387`**
```tis
    centerize(scaleIt(window_width), scaleIt(window_height));
```
→
```tis
    centerize(window_width, window_height);
```

`window_width`/`window_height` روی ۴۰۰ می‌مانند (`:8-9`) و تغییر نمی‌کنند.

---

## ۲) حذف آیکون سه‌نقطه

**`src/ui/index.tis:506-509`**
```tis
        return <div #myid>
            {this.renderPop()}
            {translate('ID')}{svg_menu}
        </div>;
```
→
```tis
        return <div #myid>
            {this.renderPop()}
            {translate('ID')}
        </div>;
```

متغیر `svg_menu` (`:48-52`) **حذف نمی‌شود**؛ `ab.tis` (`:42`, `:365`, `:376`) از همان استفاده می‌کند.

**`src/ui/index.tis:555-565`** — این handler و تابع فقط برای آیکون حذف‌شده وجود داشتند و بعد از این تغییر هرگز اجرا نمی‌شوند؛ حذفشان مستقیماً ناشی از همین تغییر است:
```tis
    event click $(svg#menu) (_, me) {
        this.showSettingMenu();
    }

    function showSettingMenu() {
        audioInputMenu.update({ show: true });
        this.toggleMenuState();
        if (direct_server) direct_server.update();
        var menu = this.$(menu#config-options);
        this.$(svg#menu).popup(menu);
    }
```
کل این بلوک حذف شود.

---

## ۳) معکوس کردن ترتیب در ردیف ID

**`src/ui/index.tis:723-726`** — `<MyIdMenu />` باید **بعد** از `.id-value` بیاید تا در `flow: horizontal` سمت راست بنشیند:
```tis
{!outgoing_only && <div .your-desktop .id-box>
    {key_confirmed ? <span .id-value><span .id-label>ID</span><input type="text" readonly value={formatId(get_id())}/></span> : translate("Generating ...")}
    <MyIdMenu />
</div>}
```

`input` دست‌نخورده می‌ماند تا شماره همچنان قابل انتخاب و کپی باشد.

---

## ۴) اصلاح fallback منوی تنظیمات

**`src/ui/index.tis:1399-1405`** — بدون این اصلاح `Ctrl+Alt+S` می‌شکند: عنصر `#open-settings` در کد وجود ندارد و fallback فعلی روی همان `svg#menu` حذف‌شده است، پس `anchor` برابر `null` می‌شود و `anchor.popup(menu)` خطا می‌دهد.
```tis
    var anchor = $(#open-settings);
    if (!anchor) anchor = myIdMenu.$(svg#menu);
```
→
```tis
    var anchor = $(#open-settings);
    if (!anchor) anchor = myIdMenu.$(div#myid);
```

`#myid` (همان div برچسب «شناسه») همیشه رندر می‌شود و popup روی موقعیت آن باز می‌شود.

---

## ۵) رنگ و چیدمان کادر

**`src/ui/index.css:456-475`** — کل بلوک `.id-box` جایگزین شود:
```css
/* Outgoing/desktop ID row. Kept separate from .your-desktop, which PasswordArea shares. */
.id-box {
    flow: horizontal;
    align-items: center;
    border: 2px solid #2DD4BF;
    border-radius: 4px;
    padding: 0.5em;
}

.id-box .id-value {
    flow: horizontal;
    align-items: center;
    width: *;
}

.id-box .id-label {
    padding-right: 0.3em;
    color: color(light-text);
}
```

- `width: *` روی `.id-value` فضای باقی‌مانده را می‌گیرد و `#myid` را به لبهٔ راست هل می‌دهد.
- `text-align: right` از `.id-label` حذف شد؛ دیگر لازم نیست.
- قاعدهٔ `div#myid svg#menu` در `index.css:391` دست‌نخورده می‌ماند چون `div#tags-label svg#menu` در `ab.tis` هنوز به آن نیاز دارد.
- `.your-desktop` (`index.css:141`) دست‌نخورده؛ `border` در `.id-box` به‌خاطر ترتیب بعدتر و specificity برابر، `border-left: accent` آن را هم بازنویسی می‌کند — همان رفتاری که الان در بیلد دیده می‌شود.

---

## سطح regression

- `view.windowMinSize/MaxSize` و `centerize()` → فقط پنجرهٔ اصلی. `remote.tis`، `cm.tis`، `install.tis` و `header.tis` که `scaleIt` دارند **عمداً دست‌نخورده** می‌مانند (پنجره‌های جدا، خارج از این درخواست).
- `get_msgbox_width()` → سقف عرض popupها هم‌تراز با پنجرهٔ کوچک‌تر.
- `MyIdMenu.render()` → فقط متن برچسب؛ popup دست‌نخورده (تنظیمات هنوز کار می‌کند).
- `showSettingMenu()` حذف می‌شود → هیچ مسیر اجرایی‌ای را قطع نمی‌کند چون تنها فراخوانش از همان handler حذف‌شده بود.
- `showSettings()` fallback → `Ctrl+Alt+S` همچنان منو را باز می‌کند.
- `.id-box` CSS → فقط ردیف ID؛ `PasswordArea` که `.your-desktop` را به‌اشتراک می‌گذارد تحت تأثیر نیست.

---

## اعتبارسنجی

1. `python3 res/inline-sciter.py` بدون خطا (خروجی `src/ui/inline.rs` tracked نیست).
2. YAML دست‌نخورده — نیازی به اعتبارسنجی مجدد ندارد.
3. push روی `rayno-branding` → ران CI؛ ریلیز جدید `RAYNODesk-1.5.0-x86-<n>` با `target_commitish` روی همان commit ساخته شود.
4. در exe ساخته‌شده بررسی شود:
   - پنجره دقیقاً ۴۰۰×۴۰۰ (روی نمایشگر ۱۲۵٪ باید کوچک‌تر از نسخهٔ قبل باشد).
   - `ID <شماره>` سمت چپ، «شناسه» سمت راست، بدون آیکون و بدون همپوشانی.
   - کادر ۲ پیکسلی فیروزه‌ای دور کل ردیف، در تم دارک و روشن.
   - شماره همچنان قابل انتخاب و کپی.
   - `Ctrl+Alt+S` منوی تنظیمات را باز می‌کند و آیتم «Remove wallpaper during incoming sessions» تیک‌خورده است.

## ریسک‌ها

- **ظاهر پنجره در exe واقعی دیده نشده.** Sciter TISX/CSS را در زمان اجرا پارس می‌کند نه در بیلد؛ اگر `width: *` یا `#2DD4BF` آنطور رندر نشد، در بیلد بعدی قابل اصلاح است. بررسی نهایی حتماً روی exe ساخته‌شده انجام شود.
- **پنجرهٔ remote session دست‌نخورده می‌ماند.** اگر همان مشکل دو‌برابر شدن DPI در آن پنجره هم وجود داشته باشد، این یک ایراد جداگانه و خارج از محدودهٔ این تغییر است.

## خارج از محدوده

- حذف کامل مسیر دسترسی به تنظیمات با ماوس (پذیرفته‌شدهٔ کاربر).
- code signing (هنوز فقط تحقیق/توصیه، بدون تغییر کد).
- پنجره‌های `remote.tis` / `cm.tis` / `install.tis`.
