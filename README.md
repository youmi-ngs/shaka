# Shaka - Photography Social Network

Shaka is a social networking app designed for photography enthusiasts to share their work and connect with other photographers.

## Features

### Core Features
- 📸 **Work Posts** - Share your photography with detailed metadata (location, camera settings, date)
- ❓ **Question Posts** - Ask questions to the community with optional image attachments
- 💬 **Comments** - Engage in discussions on posts
- ❤️ **Likes & Bookmarks** - Show appreciation and save posts for later
- 👥 **Follow System** - Follow photographers you admire
- 🔍 **Search** - Find posts by title, tags, or users
- 🚨 **Report System** - Report inappropriate content with email notifications to admins

### Safety & Security
- 🔒 Comprehensive Firebase security rules
- 📜 Terms of Service and Privacy Policy
- ✉️ Email notifications for reported content
- 🛡️ Anonymous authentication with Apple ID linking

## Tech Stack

- **Frontend**: SwiftUI
- **Backend**: Firebase (Firestore, Storage, Auth, Functions)
- **Push Notifications**: Firebase Cloud Messaging
- **Email Service**: Nodemailer with Gmail SMTP

## Setup

1. Clone the repository
2. Install Firebase CLI: `npm install -g firebase-tools`
3. Add your `GoogleService-Info.plist` to the Shaka folder
4. Run `npm install` in the functions directory
5. Configure Firebase project settings
6. Deploy Firebase rules and functions

## Project Structure

```
Shaka/
├── Shaka/              # iOS app source code
├── functions/          # Firebase Cloud Functions
├── firestore.rules     # Firestore security rules
├── storage.rules       # Storage security rules
└── firebase.json       # Firebase configuration
```

## Version

Current Version: 1.0 (Ready for TestFlight)

## License

Private project - All rights reserved

## Author

Youmi Nagase
EOF < /dev/null