# Put Loot the Egg on Google (Firebase Hosting)

> Repo note: run `npm run build:site` first. It builds `dist/` (landing page + game). In this repo `hosting/firebase.json` serves `../dist`; when the steps below say the `public` folder, use `dist`.


Firebase Hosting is Google's free website hosting. Your game ends up at an address like
https://YOUR-PROJECT-ID.web.app and the game itself is at https://YOUR-PROJECT-ID.web.app/play/

You need: a Google account, and Node.js installed (download from nodejs.org, the "LTS" version).

## 1. Make a Firebase project (in your browser)
1. Go to https://console.firebase.google.com and sign in with your Google account.
2. Click "Create a project" (or "Add project"). Give it a name, for example `loot-the-egg`. You can skip Google Analytics.
3. Remember the **Project ID** it shows (for example `loot-the-egg-4821`). That becomes your web address.
4. Keep the free plan (Spark). You don't need to add a card.

## 2. Install the Firebase tool (in a terminal or Command Prompt)
```
npm install -g firebase-tools
firebase login
```
A browser window opens so you can sign in to Google.

## 3. Connect this folder to your project
Open the terminal INSIDE this folder (the one that contains firebase.json and the public folder), then:
```
firebase use --add
```
Pick your project from the list and give it the nickname `default`.
(Do NOT run `firebase init`. The folder is already set up, and init would ask questions you don't need.)

## 4. Publish
```
firebase deploy --only hosting
```
When it finishes it prints the **Hosting URL**. Open it. Your site is live. Click "Play now" to start the game.

## Updating later
Replace `public/play/index.html` with the newest game file, then run `firebase deploy --only hosting` again.

## Getting it to show up in Google Search
Being online does not put a site in search results by itself.
1. Go to https://search.google.com/search-console and add your web.app address as a property.
2. Use "URL inspection", paste your address, and click "Request indexing".
3. It can take from a few days to a few weeks before it appears. Searching your exact game name plus "web.app" is the quickest way to check.

## Good to know
- Saves live in each player's own browser, separately for every web address.
- Free plan limits (about 1 GB stored and 10 GB of downloads a month) are plenty for a game this size (about 160 KB).
