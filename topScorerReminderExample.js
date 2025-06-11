const express = require('express');
const { 
  sendTopScorerReminderNotification,
  sendTopScorerReminderToMultipleUsers,
  sendTopScorerReminderBatch,
  createTopScorerReminderRoute
} = require('./topScorerReminderNotification');

const app = express();
app.use(express.json());

// Route for sending top scorer reminders
app.post('/send-top-scorer-reminder', createTopScorerReminderRoute());

// Example usage functions

/**
 * Example: Send reminder to a single user
 */
async function sendReminderToSingleUser() {
  try {
    const userToken = "user_fcm_token_here";
    const tournamentData = {
      tournamentId: "euro2024",
      tournamentName: "UEFA Euro 2024",
      leagueId: "4", // European Championship league ID
      deadline: new Date('2024-06-15T12:00:00Z') // Tournament start date
    };
    
    const messageId = await sendTopScorerReminderNotification(
      userToken, 
      tournamentData, 
      "user123"
    );
    
    console.log('Single user notification sent:', messageId);
  } catch (error) {
    console.error('Error:', error);
  }
}

/**
 * Example: Send reminders to multiple users
 */
async function sendReminderToMultipleUsers() {
  try {
    const users = [
      { token: "user1_fcm_token", userId: "user1" },
      { token: "user2_fcm_token", userId: "user2" },
      { token: "user3_fcm_token", userId: "user3" }
    ];
    
    const tournamentData = {
      tournamentId: "worldcup2026",
      tournamentName: "FIFA World Cup 2026",
      leagueId: "1", // World Cup league ID
      deadline: new Date('2026-06-11T15:00:00Z')
    };
    
    const results = await sendTopScorerReminderToMultipleUsers(users, tournamentData);
    
    console.log('Multiple users notification results:', results);
  } catch (error) {
    console.error('Error:', error);
  }
}

/**
 * Example: Send batch reminders (efficient for large groups)
 */
async function sendBatchReminder() {
  try {
    const tokens = [
      "token1", "token2", "token3", // ... up to 500 tokens
    ];
    
    const tournamentData = {
      tournamentId: "premierleague2024",
      tournamentName: "Premier League 2024/25",
      leagueId: "39", // Premier League ID
      deadline: new Date('2024-08-16T18:00:00Z')
    };
    
    const result = await sendTopScorerReminderBatch(tokens, tournamentData);
    
    console.log('Batch notification result:', result);
  } catch (error) {
    console.error('Error:', error);
  }
}

/**
 * Example: Scheduled reminder job (using node-cron or similar)
 */
function scheduleTopScorerReminders() {
  // This would typically use a cron job library like node-cron
  // const cron = require('node-cron');
  
  // Example: Send reminders 24 hours before deadline
  // cron.schedule('0 9 * * *', async () => {
  //   console.log('Running daily top scorer reminder check...');
  //   
  //   // Get tournaments with deadlines in next 24 hours
  //   const upcomingTournaments = await getUpcomingTournamentDeadlines();
  //   
  //   for (const tournament of upcomingTournaments) {
  //     const users = await getUsersForTournament(tournament.id);
  //     const tokens = users.map(user => user.fcmToken).filter(Boolean);
  //     
  //     if (tokens.length > 0) {
  //       await sendTopScorerReminderBatch(tokens, tournament);
  //       console.log(`Sent reminders for ${tournament.name} to ${tokens.length} users`);
  //     }
  //   }
  // });
}

/**
 * API endpoint examples for testing
 */

// Test single user reminder
app.post('/test/single-reminder', async (req, res) => {
  try {
    const { userToken, userId } = req.body;
    
    const tournamentData = {
      tournamentId: "test_tournament",
      tournamentName: "Test Tournament",
      leagueId: "39",
      deadline: new Date(Date.now() + 24 * 60 * 60 * 1000) // 24 hours from now
    };
    
    const messageId = await sendTopScorerReminderNotification(userToken, tournamentData, userId);
    res.json({ success: true, messageId });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Test multiple users reminder
app.post('/test/multiple-reminders', async (req, res) => {
  try {
    const { users } = req.body; // Array of {token, userId}
    
    const tournamentData = {
      tournamentId: "test_tournament_multi",
      tournamentName: "Test Tournament Multi",
      leagueId: "39",
      deadline: new Date(Date.now() + 48 * 60 * 60 * 1000) // 48 hours from now
    };
    
    const results = await sendTopScorerReminderToMultipleUsers(users, tournamentData);
    res.json({ success: true, results });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * Webhook example for tournament management system
 */
app.post('/webhook/tournament-reminder', async (req, res) => {
  try {
    const { 
      tournamentId, 
      tournamentName, 
      leagueId, 
      deadlineHours, 
      userTokens 
    } = req.body;
    
    const deadline = new Date(Date.now() + deadlineHours * 60 * 60 * 1000);
    
    const tournamentData = {
      tournamentId,
      tournamentName,
      leagueId,
      deadline
    };
    
    let result;
    if (userTokens.length > 500) {
      result = await sendTopScorerReminderBatch(userTokens, tournamentData);
    } else {
      const users = userTokens.map(token => ({ token }));
      result = await sendTopScorerReminderToMultipleUsers(users, tournamentData);
    }
    
    res.json({ success: true, result });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

module.exports = {
  sendReminderToSingleUser,
  sendReminderToMultipleUsers,
  sendBatchReminder,
  scheduleTopScorerReminders
}; 