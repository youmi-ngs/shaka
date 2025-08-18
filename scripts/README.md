# Maintenance Scripts

This directory contains maintenance and migration scripts for the Shaka app.

## Scripts

- `backfill_displaynames.js` - Backfill display names for existing users
- `backfill-users.js` - Migrate user data structure
- `check-following.js` - Check following relationships
- `check-user.js` - Verify user data structure
- `check-work-fields.js` - Validate work post fields
- `migrate-cli.sh` - CLI for running migrations
- `test-user-read.js` - Test user data reading
- `update-stats.js` - Update user statistics

## Usage

1. Install dependencies:
```bash
npm install
```

2. Run a script:
```bash
node script-name.js
```

Note: These scripts require Firebase Admin SDK credentials.