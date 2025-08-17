const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// 管理者のメールアドレス（環境変数で設定）
const ADMIN_EMAIL = functions.config().admin?.email || 'your-email@example.com';

// Gmailの設定（環境変数で設定）
const GMAIL_EMAIL = functions.config().gmail?.email || 'your-gmail@gmail.com';
const GMAIL_PASSWORD = functions.config().gmail?.password || 'your-app-password';

// メール送信用のトランスポーター
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: GMAIL_EMAIL,
    pass: GMAIL_PASSWORD
  }
});

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

    // マルチキャスト送信を個別送信に変更（新しいAPIを使用）
    const responses = await Promise.allSettled(
      tokens.map(token => 
        messaging.send({
          token: token,
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
          data: data
        })
      )
    );
    
    // レスポンスを処理し、失敗したトークンをクリーンアップ
    let successCount = 0;
    let failureCount = 0;
    const failedTokens = [];
    
    responses.forEach((result, idx) => {
      if (result.status === 'fulfilled') {
        successCount++;
        console.log(`✅ Notification sent to token ${tokens[idx]}`);
      } else {
        failureCount++;
        failedTokens.push(tokens[idx]);
        console.error(`❌ Failed to send to token ${tokens[idx]}:`, result.reason);
      }
    });

    // 無効なトークンを削除
    if (failedTokens.length > 0) {
      const deletePromises = failedTokens.map(token =>
        db.collection('users_private')
          .doc(targetUid)
          .collection('fcmTokens')
          .doc(token)
          .delete()
      );
      await Promise.all(deletePromises);
      console.log(`Deleted ${failedTokens.length} invalid tokens`);
    }

    console.log(`Push notification results: ${successCount} success, ${failureCount} failed`);
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

/**
 * 通報通知（管理者向け）
 * 新しい通報が作成されたときに管理者に通知を送る
 */
exports.onReportCreated = functions.firestore
  .document('reports/{reportId}')
  .onCreate(async (snap, context) => {
    const report = snap.data();
    const reportId = context.params.reportId;
    
    try {
      // 通報者の情報を取得
      const reporterDoc = await db.collection('users').doc(report.reporterId).get();
      const reporterName = reporterDoc.exists && reporterDoc.data().public
        ? reporterDoc.data().public.displayName
        : 'Anonymous';

      // 通報対象の情報を取得
      let targetTitle = report.targetTitle || 'Unknown';
      let targetUrl = '';
      
      // Firebase Consoleの直接リンクを生成
      const projectId = process.env.GCLOUD_PROJECT || 'shaka-shakatsu';
      const consoleUrl = `https://console.firebase.google.com/project/${projectId}/firestore/data/~2Freports~2F${reportId}`;

      // 管理者通知用のドキュメントを作成（オプション）
      await db.collection('admin_notifications').add({
        type: 'report',
        reportId: reportId,
        reporterId: report.reporterId,
        reporterName: reporterName,
        targetType: report.targetType,
        targetId: report.targetId,
        targetTitle: targetTitle,
        reason: report.reason,
        reasonDescription: report.reasonDescription,
        additionalDetails: report.additionalDetails || '',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        reviewed: false,
        consoleUrl: consoleUrl
      });

      console.log(`New report created: ${reportId}`);
      console.log(`Report type: ${report.targetType}`);
      console.log(`Reason: ${report.reason}`);
      console.log(`Reporter: ${reporterName}`);
      console.log(`Target: ${targetTitle}`);
      console.log(`View in Firebase Console: ${consoleUrl}`);
      
      // メール通知を送信
      if (ADMIN_EMAIL !== 'your-email@example.com' && GMAIL_EMAIL !== 'your-gmail@gmail.com') {
        const mailOptions = {
          from: GMAIL_EMAIL,
          to: ADMIN_EMAIL,
          subject: '⚠️ 新しい通報がありました - Shaka App',
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
              <div style="background-color: #f44336; color: white; padding: 20px; border-radius: 10px 10px 0 0;">
                <h2 style="margin: 0;">⚠️ 新しい通報を受信しました</h2>
              </div>
              <div style="background-color: #f5f5f5; padding: 20px; border-radius: 0 0 10px 10px;">
                <h3 style="color: #333;">通報の詳細</h3>
                <table style="width: 100%; border-collapse: collapse;">
                  <tr>
                    <td style="padding: 10px; border-bottom: 1px solid #ddd;"><strong>通報ID:</strong></td>
                    <td style="padding: 10px; border-bottom: 1px solid #ddd;">${reportId}</td>
                  </tr>
                  <tr>
                    <td style="padding: 10px; border-bottom: 1px solid #ddd;"><strong>種類:</strong></td>
                    <td style="padding: 10px; border-bottom: 1px solid #ddd;">${report.targetType}</td>
                  </tr>
                  <tr>
                    <td style="padding: 10px; border-bottom: 1px solid #ddd;"><strong>理由:</strong></td>
                    <td style="padding: 10px; border-bottom: 1px solid #ddd;">${report.reason}</td>
                  </tr>
                  <tr>
                    <td style="padding: 10px; border-bottom: 1px solid #ddd;"><strong>理由の説明:</strong></td>
                    <td style="padding: 10px; border-bottom: 1px solid #ddd;">${report.reasonDescription}</td>
                  </tr>
                  <tr>
                    <td style="padding: 10px; border-bottom: 1px solid #ddd;"><strong>通報者:</strong></td>
                    <td style="padding: 10px; border-bottom: 1px solid #ddd;">${reporterName}</td>
                  </tr>
                  <tr>
                    <td style="padding: 10px; border-bottom: 1px solid #ddd;"><strong>対象:</strong></td>
                    <td style="padding: 10px; border-bottom: 1px solid #ddd;">${targetTitle}</td>
                  </tr>
                  ${report.additionalDetails ? `
                  <tr>
                    <td style="padding: 10px; border-bottom: 1px solid #ddd;"><strong>詳細:</strong></td>
                    <td style="padding: 10px; border-bottom: 1px solid #ddd;">${report.additionalDetails}</td>
                  </tr>
                  ` : ''}
                  <tr>
                    <td style="padding: 10px;"><strong>日時:</strong></td>
                    <td style="padding: 10px;">${new Date().toLocaleString('ja-JP', { timeZone: 'Asia/Tokyo' })}</td>
                  </tr>
                </table>
                <div style="margin-top: 20px; text-align: center;">
                  <a href="${consoleUrl}" style="display: inline-block; background-color: #4CAF50; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px;">
                    Firebase Consoleで確認
                  </a>
                </div>
              </div>
            </div>
          `
        };

        try {
          await transporter.sendMail(mailOptions);
          console.log('Email notification sent successfully');
        } catch (error) {
          console.error('Error sending email notification:', error);
        }
      }
      
      // Slackやメール通知を実装する場合はここに追加
      // 例: Slack Webhook
      /*
      if (functions.config().slack?.webhook_url) {
        const axios = require('axios');
        await axios.post(functions.config().slack.webhook_url, {
          text: `⚠️ New Report Received`,
          blocks: [
            {
              type: 'section',
              text: {
                type: 'mrkdwn',
                text: `*New Report in Shaka App*\n*Type:* ${report.targetType}\n*Reason:* ${report.reason}\n*Reporter:* ${reporterName}\n*Target:* ${targetTitle}`
              }
            },
            {
              type: 'actions',
              elements: [
                {
                  type: 'button',
                  text: {
                    type: 'plain_text',
                    text: 'View in Firebase Console'
                  },
                  url: consoleUrl
                }
              ]
            }
          ]
        });
      }
      */

      return null;
    } catch (error) {
      console.error('Error in onReportCreated:', error);
      return null;
    }
  });