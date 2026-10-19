# Super Speed Reader Ultra for iPad: cloud build

GitHub builds the app on one of its Macs and gives you a `.ipa` file. Sideloadly then installs it on your iPad with your Apple ID. You don't need Xcode.

## 1. Put this project on GitHub
1. Sign in at github.com (a free account works) and create a new repository called `speed-reader-ipad`. Private is fine.
2. Upload everything in this folder, including the hidden `.github` folder. That folder holds the build instructions.
   - Easiest: connect GitHub to Claude and Claude pushes it for you.
   - By hand on a Mac: in Finder, press Cmd+Shift+. to show hidden folders, then drag everything into the repo's **Add file → Upload files** page.

## 2. Let GitHub build it (about 10 minutes)
1. Open the repo's **Actions** tab. A run called **Build iPad app (.ipa)** starts by itself on every upload. To start one manually, choose **Run workflow**.
2. When it shows a green check, open the run and download **SpeedReaderUltra-ipa** under **Artifacts**. Unzip it to get `SpeedReaderUltra.ipa`.
3. If it shows a red ✕, download **build-log** and send it to Claude.

## 3. Install on the iPad with Sideloadly
1. Install Sideloadly on your Mac from sideloadly.io.
2. Plug in the iPad, unlock it, and tap **Trust**.
3. Drag `SpeedReaderUltra.ipa` into Sideloadly, enter your Apple ID, and click **Start**.
4. On the iPad:
   - Turn on **Settings → Privacy & Security → Developer Mode** and restart the iPad when asked.
   - Go to **Settings → General → VPN & Device Management**, tap your Apple ID, then tap **Trust**.
5. Open **Speed Reader Ultra** from the home screen.

### The 7-day limit
Apple stops apps installed with a free Apple ID from opening after 7 days. To renew, reinstall the same `.ipa` with Sideloadly. Your books and progress stay. AltStore (altstore.io) can renew the app over Wi-Fi without plugging in, as long as AltServer is running on your Mac.

## Adding books on the iPad
- **Library → Add a book:** pick files from Files or iCloud Drive. You can select several at once.
- **From the Mac app:** click **Send all to iPad**, then on the iPad open iCloud Drive → **Speed Reader** → Select All.
- **Share from Files, Books or Mail:** choose **Speed Reader Ultra** from the share menu.
