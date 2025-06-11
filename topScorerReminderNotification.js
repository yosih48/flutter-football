const admin = require('firebase-admin');

// Initialize Firebase Admin SDK (uncomment and configure if not already done)
// const serviceAccount = require('./path/to/your/firebase-service-account-key.json');
// admin.initializeApp({
//   credential: admin.credential.cert(serviceAccount)
// });

/**
 * Send a top scorer reminder notification to users
 * @param {string} userToken - FCM token of the user
 * @param {Object} tournamentData - Tournament information
 * @param {string} tournamentData.tournamentId - ID of the tournament
 * @param {string} tournamentData.tournamentName - Name of the tournament
 * @param {string} tournamentData.leagueId - League ID for navigation
 * @param {Date} tournamentData.deadline - Deadline for selecting top scorer
 * @param {string} [userId] - Optional user ID for personalization
 * @returns {Promise<string>} - Message ID if successful
 */
async function sendTopScorerReminderNotification(userToken, tournamentData, userId = null) {
  try {
    // Format deadline for display
    const deadlineFormatted = tournamentData.deadline.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });

    const message = {
      notification: {
        title: "⚽ Choose Your Top Scorer!",
        body: `Don't forget to pick your top scorer for ${tournamentData.tournamentName}. Deadline: ${deadlineFormatted}`
      },
      data: {
        action_type: "navigate",
        route_name: "/games", // Navigate to games screen where user can select top scorer
        route_params: JSON.stringify({
          tournamentId: tournamentData.tournamentId.toString(),
          league: tournamentData.leagueId.toString(),
          userId: userId || '',
          action: "select_top_scorer", // Additional context for the games screen
          deadline: tournamentData.deadline.toISOString()
        })
      },
      token: userToken,
      // Set high priority for important reminders
      android: {
        priority: "high",
        notification: {
          channel_id: "high_importance_channel",
          priority: "high",
          default_sound: true,
          default_vibrate_timings: true,
          notification_count: 1
        }
      },
      apns: {
        headers: {
          "apns-priority": "10"
        },
        payload: {
          aps: {
            sound: "default",
            badge: 1
          }
        }
      }
    };

    const response = await admin.messaging().send(message);
    console.log('Top scorer reminder notification sent successfully:', response);
    return response;
  } catch (error) {
    console.error('Error sending top scorer reminder notification:', error);
    throw error;
  }
}

/**
 * Send top scorer reminder to multiple users
 * @param {Array<Object>} users - Array of user objects with token and optional userId
 * @param {Object} tournamentData - Tournament information
 * @returns {Promise<Array>} - Array of results for each user
 */
async function sendTopScorerReminderToMultipleUsers(users, tournamentData) {
  const results = [];
  
  for (const user of users) {
    try {
      const messageId = await sendTopScorerReminderNotification(
        user.token, 
        tournamentData, 
        user.userId
      );
      results.push({ 
        userId: user.userId, 
        token: user.token, 
        success: true, 
        messageId 
      });
    } catch (error) {
      results.push({ 
        userId: user.userId, 
        token: user.token, 
        success: false, 
        error: error.message 
      });
    }
  }
  
  return results;
}

/**
 * Send batch top scorer reminders using FCM's multicast feature (more efficient for large groups)
 * @param {Array<string>} tokens - Array of FCM tokens
 * @param {Object} tournamentData - Tournament information
 * @returns {Promise<Object>} - Batch send results
 */
async function sendTopScorerReminderBatch(tokens, tournamentData) {
  try {
    const deadlineFormatted = tournamentData.deadline.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });

    const message = {
      notification: {
        title: "⚽ Choose Your Top Scorer!",
        body: `Don't forget to pick your top scorer for ${tournamentData.tournamentName}. Deadline: ${deadlineFormatted}`
      },
      data: {
        action_type: "navigate",
        route_name: "/games",
        route_params: JSON.stringify({
          tournamentId: tournamentData.tournamentId.toString(),
          league: tournamentData.leagueId.toString(),
          action: "select_top_scorer",
          deadline: tournamentData.deadline.toISOString()
        })
      },
      tokens: tokens,
      android: {
        priority: "high",
        notification: {
          channel_id: "high_importance_channel",
          priority: "high",
          default_sound: true,
          default_vibrate_timings: true
        }
      },
      apns: {
        headers: {
          "apns-priority": "10"
        },
        payload: {
          aps: {
            sound: "default",
            badge: 1
          }
        }
      }
    };

    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`Batch notification sent. Success: ${response.successCount}, Failed: ${response.failureCount}`);
    
    // Log failed tokens for debugging
    if (response.failureCount > 0) {
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          console.error(`Failed to send to token ${tokens[idx]}:`, resp.error);
        }
      });
    }
    
    return response;
  } catch (error) {
    console.error('Error sending batch top scorer reminder notifications:', error);
    throw error;
  }
}

/**
 * Express.js route handler for sending top scorer reminders
 */
function createTopScorerReminderRoute() {
  return async (req, res) => {
    try {
      const { 
        userToken, 
        users, 
        tournamentId, 
        tournamentName, 
        leagueId, 
        deadline,
        userId 
      } = req.body;

      // Validate required fields
      if (!tournamentId || !tournamentName || !leagueId || !deadline) {
        return res.status(400).json({ 
          error: 'Missing required fields: tournamentId, tournamentName, leagueId, deadline' 
        });
      }

      const tournamentData = {
        tournamentId,
        tournamentName,
        leagueId,
        deadline: new Date(deadline)
      };

      // Validate deadline
      if (isNaN(tournamentData.deadline.getTime())) {
        return res.status(400).json({ error: 'Invalid deadline format' });
      }

      let result;

      if (userToken) {
        // Send to single user
        const messageId = await sendTopScorerReminderNotification(userToken, tournamentData, userId);
        result = { success: true, messageId };
      } else if (users && Array.isArray(users)) {
        // Send to multiple users
        if (users.length > 500) {
          // Use batch method for large groups
          const tokens = users.map(user => user.token);
          result = await sendTopScorerReminderBatch(tokens, tournamentData);
        } else {
          // Use individual sends for smaller groups
          result = await sendTopScorerReminderToMultipleUsers(users, tournamentData);
        }
      } else {
        return res.status(400).json({ 
          error: 'Either userToken or users array must be provided' 
        });
      }

      res.json(result);
    } catch (error) {
      console.error('Error in top scorer reminder route:', error);
      res.status(500).json({ error: 'Failed to send top scorer reminder notification' });
    }
  };
}

module.exports = {
  sendTopScorerReminderNotification,
  sendTopScorerReminderToMultipleUsers,
  sendTopScorerReminderBatch,
  createTopScorerReminderRoute
}; 