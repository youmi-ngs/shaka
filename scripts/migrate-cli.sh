#!/bin/bash

# Firebase CLI を使った移行スクリプト（Admin SDK不要）
# 注意：このスクリプトは読み取り専用で、実際の更新は手動で行う必要があります

echo "🔍 Checking current user data structure..."

# 現在のユーザーデータを確認
firebase firestore:get users --limit 5 > current-users.json

echo "📋 Current users saved to current-users.json"
echo "Please review and determine if migration is needed."

# 既存のユーザーIDリストを取得
echo "🔎 Fetching all user IDs..."
firebase firestore:get users --limit 1000 | grep -E '^\s+[a-zA-Z0-9]{20,}:' | sed 's/://g' | sed 's/^ *//g' > user-ids.txt

echo "✅ Found $(wc -l < user-ids.txt) users"

# 各ユーザーのdisplayNameを確認
echo "📊 Checking displayName for each user:"
while read -r uid; do
    echo -n "User $uid: "
    firebase firestore:get users/$uid 2>/dev/null | grep -E "displayName:" || echo "No displayName"
done < user-ids.txt

echo ""
echo "📝 Migration recommendation:"
echo "1. If most users already have displayName, manual migration might be easier"
echo "2. Use the Firestore Console to manually update users without proper structure"
echo "3. Or continue with service account key approach after cleaning up old keys"