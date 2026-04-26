# visdir

A clean, modern, fully configurable **visual directory** template.

Build beautiful, responsive directories with live webpage thumbnails, interactive maps, contact forms, and dark mode — all driven by a single JSON file.

Perfect for churches, clubs, teams, resources, businesses, schools, or any collection of entities.

---

## Features

- Beautiful card layout with **auto-updating** webpage thumbnails
- Interactive Leaflet map with location pins
- Dark / Light mode toggle
- Clickable phone, email, social links, and Google Maps
- Secure anti-spam contact form
- Everything configurable via one `data.json` file

---

## Quick Start

### 1. Clone the repository

```bash
cd /var/www
git clone https://github.com/seancrites/visdir.git
cd visdir
```

### 2. Copy files to your web server

```bash
# Example for Apache
cp -r public_html/* /var/www/html/

# Or create a symlink (adjust paths as needed)
ln -s $(pwd)/public_html /var/www/html/visdir
```

### 3. Configure the project

#### a. Edit `public_html/data.json`

Update `public_html/data.json` with your own site info and entities.

##### Site fields

| Field | Type | Description |
| ------- | ------ | ------------- |
| `name` | string | Site title displayed in the nav and header |
| `slogan` | string | Subtitle shown under the site name |
| `motto` | string | Short phrase displayed in the footer |
| `year` | number | Copyright year |
| `maintainer` | string | Name shown in the footer as "Maintained by [name]" (omit to hide) |
| `show_contact` | boolean | Set to `true` to show a "Contact" link in the footer |
| `contact_label` | string | Label shown before each entity's `contact_name` in the cards (default: `Contact`) |
| `support_url` | string | URL for the support link in the footer |
| `support_label` | string | Label for the support link (shown only if `support_url` is also set) |
| `logo_svg` | string | Inline SVG markup for the nav logo |

##### Entity fields

Each object in the `entities` array supports:

| Field | Type | Description |
| ------- | ------ | ------------- |
| `slug` | string | Unique identifier used for the thumbnail filename |
| `name` | string | Display name of the entity |
| `city` | string | City name |
| `address` | string | Full street address |
| `website` | string | URL of the entity's website (required for thumbnail generation) |
| `contact_name` | string | Name of the contact/leader |
| `contact_email` | string | Contact person's email address |
| `phone` | string | Phone number (clickable) |
| `email` | string | Email address (clickable) |
| `stream_url` | string | Live stream URL |
| `facebook` | string | Facebook page URL |
| `youtube` | string | YouTube channel URL |
| `lat` | number | Latitude for the map pin |
| `lng` | number | Longitude for the map pin |
| `take_thumbnail` | boolean | Set to `false` to skip thumbnail generation for this entity |

##### Footer behavior

The footer is built dynamically from the `site` fields above:

- If `maintainer` is set: `Maintained by [maintainer]`
- If `show_contact` is `true`: `Contact` → links to `contact.html`
- If `support_url` and `support_label` are set: `[support_label]` → links to `support_url`
- Always ends with: `Built with VisDir` → links to `https://github.com/seancrites/visdir`

Examples:

- Everything on: `Maintained by John Doe • Contact • Support • Built with VisDir`
- Everything off: `Built with VisDir`

#### b. Update `public_html/contact.php`

Set your email address and from-domain:

```php
$to = "you@example.com";                         // ← Your email
$headers = "From: no-reply@yourdomain.com\r\n";  // ← Your domain
```

#### c. Update `public_html/sitemap.xml`

Replace `https://yourdomain.com` with your actual domain.

#### d. Update `public_html/robots.txt`

Replace `https://yourdomain.com` with your actual domain.

#### e. Update SEO tags in `public_html/index.html`

Replace these placeholders with your domain:

```html
<meta property="og:url" content="https://yourdomain.com">
<link rel="canonical" href="https://yourdomain.com">
```

### 4. Set up the Python environment and run the thumbnail updater

```bash
# Create venv (run once)
python3 -m venv ~/visdir-env

# Install dependencies
source ~/visdir-env/bin/activate
pip install --upgrade pip
pip install playwright pillow
playwright install chromium
```

#### Optional: JSON ↔ CSV converter

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

#### Configure the helper script paths

Open `scripts/update-thumbnails.sh` and verify or update these two variables near the top:

```bash
VENV_DIR="${HOME}/visdir-env"                    # Path to the Python venv you created above
SCRIPTS_DIR="$(dirname "$(realpath "$0")")"    # Usually auto-detected; change only if needed
```

#### Configure the Python script path

Open `scripts/update-thumbnails.py` and verify this variable near the top:

```python
PROJECT_DIR = Path("../public_html").resolve()   # Points to your HTML files
```

If your project is at `/var/www/visdir` and the script is in `scripts/`, the default `../public_html` resolves correctly. If your layout is different, change it to an absolute path like `Path("/var/www/visdir/public_html")`.

Run the updater:

```bash
./scripts/update-thumbnails.sh
```

### 5. Deploy

Visit your site in a browser. Thumbnails will appear in `public_html/thumbnails/`.

---

## Automate with Cron

To keep thumbnails fresh automatically, add a cronjob that runs the updater on a schedule (e.g., daily at 3 AM):

```bash
# Open your crontab
crontab -e

# Add this line to run daily at 3:00 AM
0 3 * * * /var/www/visdir/scripts/update-thumbnails.sh >/dev/null 2>&1
```

Adjust the path and schedule to match your server setup.

---

## License

This project is licensed under the **GNU General Public License v3.0** (GPL-3.0).

See [LICENSE](LICENSE) for details.
