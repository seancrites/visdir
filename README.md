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
- GPL-3.0 licensed – free to fork and use

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

### 3. Edit `data.json`

Update `public_html/data.json` with your own entities.

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

**Configure the helper script paths**

Open `scripts/update-thumbnails.sh` and verify or update these two variables near the top:

```bash
VENV_DIR="${HOME}/visdir-env"                    # Path to the Python venv you created above
SCRIPTS_DIR="$(dirname "$(realpath "$0")")"    # Usually auto-detected; change only if needed
```

If you cloned the project to a different location (e.g., `/opt/visdir` instead of `/var/www/visdir`), update `SCRIPTS_DIR` to the absolute path of the `scripts/` folder so the updater knows where `public_html/` (or your HTML files) lives.

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

---

Made with ❤️ by the open-source community.
