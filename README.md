# Study Feed (iOS)

A personal iPhone app that replaces social-media scrolling with a feed of short IT lessons:
networking, security, AI and software engineering. One user, no accounts.

The backend is a separate repo: [study-feed-server](https://github.com/hlum/study-feed-server).
It generates the cards with Claude on a home server and is reachable only over Tailscale.
The API contract is in [docs/API.md](docs/API.md).

## Run it

1. Open `StudyFeed.xcodeproj` in Xcode. It targets iOS 18, iPhone, portrait.
2. Run on a simulator or device. On the **You** tab, set **Server** to your server's address,
   e.g. `http://<tailscale-ip>:8001`. The phone must be on the same tailnet.
3. `Cmd+U` runs the unit tests. They decode real server responses saved in
   `StudyFeedTests/Fixtures`.

## Look

Dark only, one peach accent (`#F5C99B`), SF Pro and SF Mono. Three card types:
poster (swipeable slides), text post, and terminal (real command or code output).

## Notes

- The app allows plain `http://` (see `Info-ATS.plist`) because the server is only reachable
  over Tailscale, which already encrypts traffic. Nothing is exposed to the public internet.
- The server address is a setting, never hard-coded. For development you can also launch with
  `-serverURL http://<tailscale-ip>:8001`; it is saved for the next launch.
- To run on a real iPhone, pick your own team in Xcode's Signing & Capabilities.
