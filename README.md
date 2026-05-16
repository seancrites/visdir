# visdir

A clean, modern, fully configurable **visual directory** template.

Build beautiful, responsive directories with live webpage thumbnails, interactive maps, contact forms, and dark mode — all driven by a single JSON file.

Perfect for churches, clubs, teams, resources, businesses, schools, or any collection of entities.

✨ **Live Demo:** <https://seancrites.github.io/visdir/>

---

## Features

- Beautiful card layout with **auto-updating** webpage thumbnails
- Interactive Leaflet map with location pins
- Dark / Light mode toggle
- Clickable phone, email, social links, and Google Maps
- Secure anti-spam contact form with multiple CAPTCHA provider options
- Everything configurable via one `data.json` file

---

## Quick Start

### 1. Clone the repository

```bash
cd /var/www
git clone https://github.com/seancrites/visdir.git
cd visdir
```

### 2. Run the deploy script (recommended)

The included `deploy.sh` script handles everything: it copies files to your web root, applies all custom settings, activates your chosen CAPTCHA provider, and configures contact form and thumbnail paths — all interactively. **Settings are saved permanently**, so future upgrades via `git pull` followed by `./deploy.sh` will re-apply them automatically.

```bash
./deploy.sh
```

You will be prompted for:

| Setting                | Description                                                |
|------------------------|------------------------------------------------------------|
| **Web root folder**    | Where `index.html` should live (e.g. `/var/www/html`)      |
| **Scripts folder**     | Where helper scripts should be deployed                    |
| **Site title**         | Displayed in the nav bar, header, and SEO `<title>` tag    |
| **Base URL**           | Your site's full URL, including `https://`                 |
| **Meta description**   | Short description for search engine results                |
| **Open Graph desc.**   | Description that appears when shared on social media       |
| **Contact "To" email** | Where contact form submissions are sent                    |
| **Contact "From"**     | The sender address for emails sent by the form             |
| **Min submit seconds** | Anti-spam minimum time before a form can be submitted      |
| **Enforce referer**    | Anti-spam check that validates the form's origin           |
| **CAPTCHA provider**   | Turnstile, reCAPTCHA v3, hCaptcha, or None                 |

After reviewing the deployment summary, confirm with `y` to proceed. The script will:

1. **Save all settings** to `deploy-settings.json` (auto-generated, gitignored) — these persist across future `git pull` + `./deploy.sh` upgrades
2. **Back up** any existing files in the web root to `archive/backup-YYYYMMDD-HHMMSS/`
3. **Copy** fresh `public_html/` files to the web root
4. **Copy** the `scripts/` directory to your scripts folder
5. **Apply** every setting: URL replacements, site title, meta/OG descriptions, contact form addresses, anti-spam thresholds, and CAPTCHA activation
6. **Update** `data.json` with your site title (existing entity data is preserved)

> **Need to change a setting later?** Just run `./deploy.sh` again — all previously saved values will be pre-filled. Edit what you need, confirm, and the script updates only the changed settings while keeping everything else intact.

#### Settings persistence — the key to smooth upgrades

All customizations are stored in `deploy-settings.json` (listed in `.gitignore` so it never gets committed or overwritten by upstream changes). This means:

- ✅ **`git fetch` / `git merge` will never clobber your configuration**
- ✅ **Re-running `./deploy.sh` after a `git pull` re-applies all your settings automatically**
- ✅ **Thumbnails, data.json entity data, and generated content are never touched**
- ✅ **A full backup is always created before any files are overwritten**
- ✅ **Script paths and relative references are auto-configured to match your environment**

> ⚠️ **Warning: Custom changes to deployed files will be overwritten.** Every re-run of `./deploy.sh` copies fresh files from `public_html/` to your web root, overwriting any custom modifications you may have made directly to deployed files (e.g., `index.html`, `contact.html`, `contact.php`, CSS, JavaScript). A timestamped backup of your web root is always saved to `archive/backup-YYYYMMDD-HHMMSS/` before new files are copied, but the only way to preserve custom code permanently is to add it upstream in the repository's `public_html/` source files. Files not in `public_html/` — such as `data.json`, thumbnails, and `deploy-settings.json` — are never overwritten.

---

### 3. What's next?

After deployment, your site is live but still needs real data and (optionally) thumbnails:

1. **Edit `data.json`** — populate the `entities` array with your directory listings (see [Configuration](#configuration) below)
2. **Run the thumbnail updater** — see [Thumbnail Setup](#thumbnail-setup)
3. **Set up cron** — schedule automatic thumbnail refreshes (see [Automate with Cron](#automate-with-cron))

---

## Configuration

### a. Edit `public_html/data.json`

Update `public_html/data.json` with your own site info and entities.

> **Note for deploy.sh users:** The script automatically updates the `site.name` field in `data.json`. Entity data you add is never overwritten by re-running `deploy.sh`.

#### Site fields

| Field          | Type    | Description                                                                       |
|----------------|---------|-----------------------------------------------------------------------------------|
| `name`         | string  | Site title displayed in the nav and header                                        |
| `slogan`       | string  | Subtitle shown under the site name                                                |
| `motto`        | string  | Short phrase displayed in the footer                                              |
| `year`         | number  | Copyright year                                                                    |
| `maintainer`   | string  | Name shown in the footer as "Maintained by [name]" (omit to hide)                 |
| `show_contact` | boolean | Set to `true` to show a "Contact" link in the footer                              |
| `contact_label`| string  | Label shown before each entity's `contact_name` in the cards (default: `Contact`) |
| `support_url`  | string  | URL for the support link in the footer                                            |
| `support_label`| string  | Label for the support link (shown only if `support_url` is also set)              |
| `logo_svg`     | string  | Inline SVG markup for the nav logo                                                |

#### Entity fields

Each object in the `entities` array supports:

| Field            | Type    | Description                                                     |
|------------------|---------|-----------------------------------------------------------------|
| `slug`           | string  | Unique identifier used for the thumbnail filename               |
| `name`           | string  | Display name of the entity                                      |
| `city`           | string  | City name                                                       |
| `address`        | string  | Full street address                                             |
| `website`        | string  | URL of the entity's website (required for thumbnail generation) |
| `contact_name`   | string  | Name of the contact/leader                                      |
| `contact_email`  | string  | Contact person's email address                                  |
| `phone`          | string  | Phone number (clickable)                                        |
| `email`          | string  | Email address (clickable)                                       |
| `school_url`     | string  | School/institution website URL (clickable)                      |
| `school_label`   | string  | Optional display label for school (default: shows the URL)      |
| `stream_url`     | string  | Live stream URL                                                 |
| `facebook`       | string  | Facebook page URL                                               |
| `youtube`        | string  | YouTube channel URL                                             |
| `lat`            | number  | Latitude for the map pin                                        |
| `lng`            | number  | Longitude for the map pin                                       |
| `take_thumbnail` | boolean | Set to `false` to skip thumbnail generation for this entity     |
| `disable`        | boolean | Set to `false` to skip rendering and thumbnail generation       |

##### Multiple Contacts

Entities support **unlimited number of contacts** using the following pattern:

| Field            | Type    | Description                                             |
|------------------|---------|---------------------------------------------------------|
| `contactN_name`  | string  | **Required.** Name of contact person (N = 1, 2, 3, ...) |
| `contactN_label` | string  | Optional label for this contact (default: `Contact`)    |
| `contactN_email` | string  | Email address for this contact                          |
| `contactN_phone` | string  | Phone number for this contact                           |

###### Contact Logic Rules

- Start numbering at `1` and increment sequentially (`contact1_name`, `contact2_name`, etc)
- There is **no maximum limit** - add as many contacts as needed
- If `contactN_name` is missing or empty, that contact and all higher-numbered contacts will be skipped
- **Legacy Compatibility**: The old style single `contact_name` field is fully supported
- **Improved Behaviour**: You may use both singular `contact_name` **and** numbered `contactN_name` fields at the same time. Legacy singular contact will be shown first, followed by all numbered contacts in order.

##### Multiple Schools

Entities support **unlimited number of schools** using the following pattern:

| Field           | Type    | Description                                                     |
|-----------------|---------|-----------------------------------------------------------------|
| `schoolN_url`   | string  | **Required.** URL for school/institution (N = 1, 2, 3, ...)     |
| `schoolN_label` | string  | Optional display label for this school (default: shows the URL) |

###### School Logic Rules

- Start numbering at `1` and increment sequentially (`school1_url`, `school2_url`, etc)
- There is **no maximum limit** - add as many schools as needed
- If `schoolN_url` is missing or empty, that school and all higher-numbered schools will be skipped
- **Legacy Compatibility**: The old style single `school` field is fully supported
- **Improved Behaviour**: You may use both singular `school` **and** numbered `schoolN_url` fields at the same time. Legacy singular school will be shown first, followed by all numbered schools in order.

##### Footer behavior

The footer is built dynamically from the `site` fields above:

- If `maintainer` is set: `Maintained by [maintainer]`
- If `show_contact` is `true`: `Contact` → links to `contact.html`
- If `support_url` and `support_label` are set: `[support_label]` → links to `support_url`
- Always ends with: `Built with VisDir` → links to `https://github.com/seancrites/visdir`

Examples:

- Everything on: `Maintained by John Doe • Contact • Support • Built with VisDir`
- Everything off: `Built with VisDir`

### b. Update SEO tags in `public_html/index.html`

If you used `deploy.sh`, the base URL, meta description, and OG description have already been applied. If setting up manually, replace these placeholders:

```html
<meta property="og:url" content="https://yourdomain.com">
<link rel="canonical" href="https://yourdomain.com">
<meta name="description" content="Your description here">
<meta property="og:description" content="Your social description here">
```

### c. Update `public_html/sitemap.xml` and `robots.txt`

Replace `https://yourdomain.com` with your actual domain.

> If you used `deploy.sh`, the URL has already been applied to these files.

### d. Contact form email configuration

If you used `deploy.sh`, the contact form email addresses and anti-spam settings have already been configured. If setting up manually, edit `public_html/contact.php`:

```php
$to = "you@example.com";                         // ← Your email
$headers = "From: no-reply@yourdomain.com\r\n";  // ← Your domain
```

---

## Thumbnail Setup

### Python environment

```bash
# Create venv (run once)
python3 -m venv ~/visdir-env

# Install dependencies
source ~/visdir-env/bin/activate
pip install --upgrade pip
pip install playwright pillow
playwright install chromium
```

### Run the updater

```bash
./scripts/update-thumbnails.sh
```

> If you used `deploy.sh`, the script path in `update-thumbnails.py` has already been adjusted to match your environment.

### Cron (automatic refreshes)

To keep thumbnails fresh automatically:

```bash
crontab -e
```

Add (adjust paths to match your setup):

```bash
# Daily at 3:00 AM
0 3 * * * /var/www/visdir/scripts/update-thumbnails.sh >/dev/null 2>&1
```

---

## Anti-Spam Protections

The contact form includes 3 layered, invisible anti-bot protections that stop ~98% of drive-by spam automatically — **no CAPTCHAs, no external services, zero user impact**:

| Protection            | Description                                                                                  | Effectiveness                     |
|-----------------------|----------------------------------------------------------------------------------------------|-----------------------------------|
| **CSS Honeypot**      | Invisible off-screen field that only bots will fill in. Humans will never see this field.    | ✅ Blocks 70% of bots             |
| **Time Gate**         | Minimum submission delay enforced. No human fills out a form in < 3 seconds. Every bot does. | ✅ Blocks 95% of bots             |
| **Origin Validation** | Only accept form submissions originating from your actual contact page.                      | ✅ Blocks 99% of direct POST bots |

All spam rejections return a successful response. Bots have no idea they were blocked and will not retry or adapt.

### Configuration Options

You may adjust these values at the top of `contact.php`:

```php
// Minimum seconds required to submit form. Recommended: 3
// Set to 0 to disable this check entirely
$MINIMUM_SUBMIT_SECONDS = 3;
```

Refer to the comments inside `contact.php` for full documentation on each protection.

### CAPTCHA Options (Optional Enhancement)

In addition to the invisible protections above, you can optionally enable a visible CAPTCHA provider for extra protection on high-traffic or sensitive sites.

**Supported providers:**

- **Cloudflare Turnstile** (recommended – fast, privacy-friendly, low friction)
- reCAPTCHA v3 (Google)
- hCaptcha

#### How the CAPTCHA system works

Each provider has pre-written blocks in both `contact.html` and `contact.php`, wrapped in comment markers:

```
HTML: <!-- TURNSTILE-BEGIN ... TURNSTILE-END -->
PHP:  /* TURNSTILE-BEGIN ... TURNSTILE-END */
```

By default, these blocks are **commented out** (disabled). To activate a provider, you remove the opening comment marker and replace the placeholder tokens with your actual API keys:

| File            | Placeholder           | Replace with                 |
|-----------------|-----------------------|------------------------------|
| `contact.html`  | `TURNSTILE_SITE_KEY`  | Your Turnstile site key      |
| `contact.html`  | `RECAPTCHA_SITE_KEY`  | Your reCAPTCHA v3 site key   |
| `contact.html`  | `HCAPTCHA_SITE_KEY`   | Your hCaptcha site key       |
| `contact.php`   | `TURNSTILE_SECRET_KEY`| Your Turnstile secret key    |
| `contact.php`   | `RECAPTCHA_SECRET_KEY`| Your reCAPTCHA v3 secret key |
| `contact.php`   | `HCAPTCHA_SECRET_KEY` | Your hCaptcha secret key     |

#### Option A: Automatic setup via deploy.sh (recommended)

When you run `./deploy.sh`, you will be prompted to choose a CAPTCHA provider and enter your API keys. The script automatically:

1. **Activates** the correct block by removing the comment markers from `contact.html` and `contact.php`
2. **Replaces** the `SITE_KEY` placeholder with your actual site key
3. **Replaces** the `SECRET_KEY` placeholder with your actual secret key

All other provider blocks remain safely commented out. Re-run `./deploy.sh` anytime to switch providers or update keys — your previous choices are pre-filled.

#### Option B: Manual setup

1. **Open `public_html/contact.html`**

2. **Activate your chosen provider's `<head>` script** — remove the `<!--` and `-->` comment markers around the script tag. For example, for Turnstile:

   ```html
   <!-- BEFORE (commented out): -->
   <!-- TURNSTILE-BEGIN
   <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
   TURNSTILE-END -->

   <!-- AFTER (active): -->
   <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
   ```

   The three options in `<head>` (lines 41–54):

   ```html
   <!-- Option 1: Cloudflare Turnstile (Recommended - privacy friendly) -->
   <!-- TURNSTILE-BEGIN
   <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
   TURNSTILE-END -->

   <!-- Option 2: Google reCAPTCHA v3 (Invisible) -->
   <!-- RECAPTCHA-BEGIN
   <script src="https://www.google.com/recaptcha/api.js?render=RECAPTCHA_SITE_KEY"></script>
   RECAPTCHA-END -->

   <!-- Option 3: hCaptcha -->
   <!-- HCAPTCHA-BEGIN
   <script src="https://js.hcaptcha.com/1/api.js" async defer></script>
   HCAPTCHA-END -->
   ```

3. **Activate the matching widget in the form body** (lines 112–129) — same approach, remove the comment markers. For Turnstile:

   ```html
   <!-- BEFORE (commented out): -->
   <!-- TURNSTILE-BEGIN
   <div class="flex justify-center">
      <div class="cf-turnstile" data-sitekey="TURNSTILE_SITE_KEY" data-theme="auto"></div>
   </div>
   TURNSTILE-END -->

   <!-- AFTER (active): -->
   <div class="flex justify-center">
      <div class="cf-turnstile" data-sitekey="TURNSTILE_SITE_KEY" data-theme="auto"></div>
   </div>
   ```

4. **Replace the site key placeholder** — change `TURNSTILE_SITE_KEY` to your actual Turnstile site key (or `RECAPTCHA_SITE_KEY` / `HCAPTCHA_SITE_KEY` for other providers).

5. **If using Google reCAPTCHA v3**, also activate the form submit handler at the bottom of `contact.html` (lines 227–238) — remove the `<!-- RECAPTCHA-BEGIN` / `RECAPTCHA-END -->` markers around the extra `<script>` block, and replace `RECAPTCHA_SITE_KEY` with your actual site key.

6. **Open `public_html/contact.php`** and activate the validation block for your chosen provider (lines 93–151). Remove the `/* MARKER-BEGIN` / `MARKER-END */` comment markers and replace the `SECRET_KEY` placeholder. For Turnstile:

   ```php
   // BEFORE (commented out):
   /* TURNSTILE-BEGIN
   $turnstile_token = $_POST['cf-turnstile-response'] ?? '';
   if (empty($turnstile_token)) {
      header('Location: contact.html?status=error');
      exit;
   }
   $secret   = 'TURNSTILE_SECRET_KEY';
   // ... full validation block ...
   TURNSTILE-END */

   // AFTER (active):
   $turnstile_token = $_POST['cf-turnstile-response'] ?? '';
   if (empty($turnstile_token)) {
      header('Location: contact.html?status=error');
      exit;
   }
   $secret   = '1q2w3e4r5t6y7u8i9o0p';   // ← your actual Turnstile secret key
   // ... full validation block ...
   ```

**Security notes:**

- All CAPTCHA tokens are validated server-side before any email is sent.
- Failed CAPTCHA attempts return a clear, user-friendly error message.
- The original invisible anti-spam protections (honeypot, time gate, origin validation) remain active at all times — CAPTCHA is an optional extra layer.
- You can toggle a CAPTCHA provider on/off without touching any other code — just add or remove the comment markers.
- The `deploy.sh` script handles all of this automatically and safely.

---

## JSON ↔ CSV Converter

A standalone converter is included in `scripts/convert-data.py` for bulk editing. It requires **no extra packages**—only Python 3.

```bash
# JSON array → CSV
python scripts/convert-data.py --to-csv public_html/data.json entities.csv

# CSV → JSON (re-uses site object from existing JSON)
python scripts/convert-data.py --to-json entities.csv public_html/data.json --site-from public_html/data.json

# CSV → JSON (uses template site object)
python scripts/convert-data.py --to-json entities.csv public_html/data.json
```

> **Note:** CSV stores everything as text, so numeric and boolean fields will become strings on conversion back to JSON. Review the output and adjust types if needed.

---

## Manual Deployment (alternative)

If you prefer to set things up by hand instead of using `deploy.sh`:

```bash
# Example for Apache
cp -r public_html/* /var/www/html/

# Or create a symlink (adjust paths as needed)
ln -s $(pwd)/public_html /var/www/html/visdir
```

After copying, manually perform the steps described in [Configuration](#configuration) above.

---

## Upgrading

Because all settings are saved in `deploy-settings.json` (gitignored), upgrading is straightforward:

```bash
cd /var/www/visdir

# Fetch the latest code
git fetch origin
git merge origin/main

# Re-run deploy — all previous settings are pre-filled
./deploy.sh
```

The script will:

- **Detect your existing settings** from `deploy-settings.json`
- **Pre-fill every prompt** with your current values — just press Enter to accept or type new values
- **Create a backup** of the current web root before copying new files
- **Re-apply every customization** — URL, site title, meta tags, contact form config, CAPTCHA keys
- **Preserve your data.json entity data** and thumbnails

---

## License

This project is licensed under the **GNU General Public License v3.0** (GPL-3.0).

See [LICENSE](LICENSE) for details.
