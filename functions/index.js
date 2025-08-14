const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * ユーザーのdisplayName変更時に、全投稿のdisplayNameを更新
 */
exports.syncDisplayName = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    const userId = context.params.userId;
    const newData = change.after.data();
    const oldData = change.before.data();

    // displayNameが変更されていない場合はスキップ
    if (newData.displayName === oldData.displayName) {
      console.log(`No displayName change for user ${userId}`);
      return null;
    }

    const newDisplayName = newData.displayName;
    console.log(`Updating displayName for user ${userId} to: ${newDisplayName}`);

    // バッチ処理の準備
    const batchArray = [];
    batchArray.push(db.batch());
    let operationCounter = 0;
    let batchIndex = 0;

    try {
      // Works コレクションの更新
      const worksQuery = await db.collection('works')
        .where('userID', '==', userId)
        .get();

      worksQuery.forEach((doc) => {
        batchArray[batchIndex].update(doc.ref, {
          displayName: newDisplayName,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        operationCounter++;

        // Firestoreのバッチは最大500操作
        if (operationCounter === 499) {
          batchArray.push(db.batch());
          batchIndex++;
          operationCounter = 0;
        }
      });

      // Questions コレクションの更新
      const questionsQuery = await db.collection('questions')
        .where('userID', '==', userId)
        .get();

      questionsQuery.forEach((doc) => {
        batchArray[batchIndex].update(doc.ref, {
          displayName: newDisplayName,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        operationCounter++;

        if (operationCounter === 499) {
          batchArray.push(db.batch());
          batchIndex++;
          operationCounter = 0;
        }
      });

      // 全バッチをコミット
      const commitPromises = batchArray.map((batch) => batch.commit());
      await Promise.all(commitPromises);

      const totalUpdated = worksQuery.size + questionsQuery.size;
      console.log(`Successfully updated ${totalUpdated} posts for user ${userId}`);
      
      return { success: true, updated: totalUpdated };

    } catch (error) {
      console.error('Error updating displayName:', error);
      throw new functions.https.HttpsError('internal', 'Failed to update displayName', error);
    }
  });

/**
 * 既存データのバックフィル用HTTPトリガー（手動実行用）
 */
exports.backfillDisplayNames = functions.https.onRequest(async (req, res) => {
  // セキュリティ：管理者のみ実行可能にする場合はトークン検証を追加
  const secretToken = req.headers.authorization;
  if (secretToken !== 'Bearer YOUR-SECRET-TOKEN') {
    res.status(401).send('Unauthorized');
    return;
  }

  try {
    const usersSnapshot = await db.collection('users').get();
    let totalUpdated = 0;

    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const displayName = userDoc.data().displayName || `User_${userId.substring(0, 6)}`;

      // Works更新
      const worksBatch = db.batch();
      const worksQuery = await db.collection('works')
        .where('userID', '==', userId)
        .get();

      worksQuery.forEach((doc) => {
        if (doc.data().displayName !== displayName) {
          worksBatch.update(doc.ref, {
            displayName: displayName,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
        }
      });

      if (worksQuery.size > 0) {
        await worksBatch.commit();
        totalUpdated += worksQuery.size;
      }

      // Questions更新
      const questionsBatch = db.batch();
      const questionsQuery = await db.collection('questions')
        .where('userID', '==', userId)
        .get();

      questionsQuery.forEach((doc) => {
        if (doc.data().displayName !== displayName) {
          questionsBatch.update(doc.ref, {
            displayName: displayName,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
        }
      });

      if (questionsQuery.size > 0) {
        await questionsBatch.commit();
        totalUpdated += questionsQuery.size;
      }
    }

    res.json({
      success: true,
      message: `Backfill completed. Updated ${totalUpdated} posts.`
    });

  } catch (error) {
    console.error('Backfill error:', error);
    res.status(500).json({ error: error.message });
  }
});

// ========== プッシュ通知関連の関数 ==========

/**
 * FCMトークンを取得してプッシュ通知を送信する共通関数
 */
async function sendPushNotification(targetUid, title, body, data = {}) {
  try {
    // ユーザーのFCMトークンを取得
    const tokensSnapshot = await db
      .collection('users_private')
      .doc(targetUid)
      .collection('fcmTokens')
      .get();

    if (tokensSnapshot.empty) {
      console.log(`No FCM tokens found for user ${targetUid}`);
      return;
    }

    const tokens = tokensSnapshot.docs.map(doc => doc.id);
    console.log(`Found ${tokens.length} FCM tokens for user ${targetUid}`);

    // 未読通知数を取得
    const unreadSnapshot = await db
      .collection('notifications')
      .doc(targetUid)
      .collection('items')
      .where('read', '==', false)
      .get();
    
    const unreadCount = unreadSnapshot.size;

    // メッセージペイロード
    const message = {
      tokens: tokens,
      notification: {
        title: title,
        body: body
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: title,
              body: body
            },
            sound: 'default',
            badge: unreadCount
          }
        }
      },
      data: {
        ...data,
        click_action: 'FLUTTER_NOTIFICATION_CLICK' // for Flutter/iOS
      }
    };

    // マルチキャスト送信
    const response = await messaging.sendMulticast(message);
    
    // 失敗したトークンをクリーンアップ
    if (response.failureCount > 0) {
      const failedTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          failedTokens.push(tokens[idx]);
          console.error(`Failed to send to token ${tokens[idx]}:`, resp.error);
        }
      });

      // 無効なトークンを削除
      const deletePromises = failedTokens.map(token =>
        db.collection('users_private')
          .doc(targetUid)
          .collection('fcmTokens')
          .doc(token)
          .delete()
      );
      await Promise.all(deletePromises);
    }

    console.log(`Push notification sent: ${response.successCount} success, ${response.failureCount} failed`);
  } catch (error) {
    console.error('Error sending push notification:', error);
  }
}

/**
 * いいね通知（Works）
 */
exports.onWorkLiked = functions.firestore
  .document('works/{workId}/likes/{likeUid}')
  .onCreate(async (snap, context) => {
    const { workId, likeUid } = context.params;
    
    try {
      // 投稿情報を取得
      const workDoc = await db.collection('works').doc(workId).get();
      if (!workDoc.exists) {
        console.log(`Work ${workId} not found`);
        return null;
      }

      const work = workDoc.data();
      const ownerUid = work.userID;

      // 自分の投稿へのいいねはスキップ
      if (ownerUid === likeUid) {
        console.log('Self-like detected, skipping notification');
        return null;
      }

      // いいねしたユーザーの情報を取得
      const likerDoc = await db.collection('users').doc(likeUid).get();
      const likerName = likerDoc.exists && likerDoc.data().public 
        ? likerDoc.data().public.displayName 
        : 'Someone';

      // 通知ドキュメントを作成
      await db.collection('notifications')
        .doc(ownerUid)
        .collection('items')
        .add({
          type: 'like',
          actorUid: likeUid,
          actorName: likerName,
          targetType: 'work',
          targetId: workId,
          message: `${likerName} liked your work`,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          read: false
        });

      // プッシュ通知を送信
      await sendPushNotification(
        ownerUid,
        'New Like',
        `${likerName} liked your work: ${work.title}`,
        {
          type: 'like',
          actorUid: likeUid,
          targetType: 'work',
          targetId: workId
        }
      );

      return null;
    } catch (error) {
      console.error('Error in onWorkLiked:', error);
      return null;
    }
  });

/**
 * いいね通知（Questions）
 */
exports.onQuestionLiked = functions.firestore
  .document('questions/{questionId}/likes/{likeUid}')
  .onCreate(async (snap, context) => {
    const { questionId, likeUid } = context.params;
    
    try {
      // 質問情報を取得
      const questionDoc = await db.collection('questions').doc(questionId).get();
      if (!questionDoc.exists) {
        console.log(`Question ${questionId} not found`);
        return null;
      }

      const question = questionDoc.data();
      const ownerUid = question.userID;

      // 自分の投稿へのいいねはスキップ
      if (ownerUid === likeUid) {
        console.log('Self-like detected, skipping notification');
        return null;
      }

      // いいねしたユーザーの情報を取得
      const likerDoc = await db.collection('users').doc(likeUid).get();
      const likerName = likerDoc.exists && likerDoc.data().public 
        ? likerDoc.data().public.displayName 
        : 'Someone';

      // 通知ドキュメントを作成
      await db.collection('notifications')
        .doc(ownerUid)
        .collection('items')
        .add({
          type: 'like',
          actorUid: likeUid,
          actorName: likerName,
          targetType: 'question',
          targetId: questionId,
          message: `${likerName} liked your question`,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          read: false
        });

      // プッシュ通知を送信
      await sendPushNotification(
        ownerUid,
        'New Like',
        `${likerName} liked your question: ${question.title}`,
        {
          type: 'like',
          actorUid: likeUid,
          targetType: 'question',
          targetId: questionId
        }
      );

      return null;
    } catch (error) {
      console.error('Error in onQuestionLiked:', error);
      return null;
    }
  });

/**
 * フォロー通知
 */
exports.onUserFollowed = functions.firestore
  .document('following/{followerUid}/users/{followedUid}')
  .onCreate(async (snap, context) => {
    const { followerUid, followedUid } = context.params;
    
    try {
      // フォローしたユーザーの情報を取得
      const followerDoc = await db.collection('users').doc(followerUid).get();
      const followerName = followerDoc.exists && followerDoc.data().public 
        ? followerDoc.data().public.displayName 
        : 'Someone';

      // 通知ドキュメントを作成
      await db.collection('notifications')
        .doc(followedUid)
        .collection('items')
        .add({
          type: 'follow',
          actorUid: followerUid,
          actorName: followerName,
          message: `${followerName} started following you`,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          read: false
        });

      // プッシュ通知を送信
      await sendPushNotification(
        followedUid,
        'New Follower',
        `${followerName} started following you`,
        {
          type: 'follow',
          actorUid: followerUid
        }
      );

      return null;
    } catch (error) {
      console.error('Error in onUserFollowed:', error);
      return null;
    }
  });

/**
 * コメント通知（Works）
 */
exports.onWorkCommented = functions.firestore
  .document('works/{workId}/comments/{commentId}')
  .onCreate(async (snap, context) => {
    const { workId, commentId } = context.params;
    const comment = snap.data();
    
    try {
      // 投稿情報を取得
      const workDoc = await db.collection('works').doc(workId).get();
      if (!workDoc.exists) {
        console.log(`Work ${workId} not found`);
        return null;
      }

      const work = workDoc.data();
      const ownerUid = work.userID;
      const commenterUid = comment.userID;

      // 自分の投稿へのコメントはスキップ
      if (ownerUid === commenterUid) {
        console.log('Self-comment detected, skipping notification');
        return null;
      }

      // コメントしたユーザーの情報を取得
      const commenterDoc = await db.collection('users').doc(commenterUid).get();
      const commenterName = commenterDoc.exists && commenterDoc.data().public 
        ? commenterDoc.data().public.displayName 
        : 'Someone';

      // コメントの冒頭を取得（最大50文字）
      const snippet = comment.text.length > 50 
        ? comment.text.substring(0, 50) + '...' 
        : comment.text;

      // 通知ドキュメントを作成
      await db.collection('notifications')
        .doc(ownerUid)
        .collection('items')
        .add({
          type: 'comment',
          actorUid: commenterUid,
          actorName: commenterName,
          targetType: 'work',
          targetId: workId,
          message: `${commenterName} commented on your work`,
          snippet: snippet,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          read: false
        });

      // プッシュ通知を送信
      await sendPushNotification(
        ownerUid,
        'New Comment',
        `${commenterName}: ${snippet}`,
        {
          type: 'comment',
          actorUid: commenterUid,
          targetType: 'work',
          targetId: workId,
          snippet: snippet
        }
      );

      return null;
    } catch (error) {
      console.error('Error in onWorkCommented:', error);
      return null;
    }
  });

/**
 * コメント通知（Questions）
 */
exports.onQuestionCommented = functions.firestore
  .document('questions/{questionId}/comments/{commentId}')
  .onCreate(async (snap, context) => {
    const { questionId, commentId } = context.params;
    const comment = snap.data();
    
    try {
      // 質問情報を取得
      const questionDoc = await db.collection('questions').doc(questionId).get();
      if (!questionDoc.exists) {
        console.log(`Question ${questionId} not found`);
        return null;
      }

      const question = questionDoc.data();
      const ownerUid = question.userID;
      const commenterUid = comment.userID;

      // 自分の投稿へのコメントはスキップ
      if (ownerUid === commenterUid) {
        console.log('Self-comment detected, skipping notification');
        return null;
      }

      // コメントしたユーザーの情報を取得
      const commenterDoc = await db.collection('users').doc(commenterUid).get();
      const commenterName = commenterDoc.exists && commenterDoc.data().public 
        ? commenterDoc.data().public.displayName 
        : 'Someone';

      // コメントの冒頭を取得（最大50文字）
      const snippet = comment.text.length > 50 
        ? comment.text.substring(0, 50) + '...' 
        : comment.text;

      // 通知ドキュメントを作成
      await db.collection('notifications')
        .doc(ownerUid)
        .collection('items')
        .add({
          type: 'comment',
          actorUid: commenterUid,
          actorName: commenterName,
          targetType: 'question',
          targetId: questionId,
          message: `${commenterName} commented on your question`,
          snippet: snippet,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          read: false
        });

      // プッシュ通知を送信
      await sendPushNotification(
        ownerUid,
        'New Comment',
        `${commenterName}: ${snippet}`,
        {
          type: 'comment',
          actorUid: commenterUid,
          targetType: 'question',
          targetId: questionId,
          snippet: snippet
        }
      );

      return null;
    } catch (error) {
      console.error('Error in onQuestionCommented:', error);
      return null;
    }
  });