# Dynamic Notification Configuration Guide

This guide explains how to configure notifications from your Node.js server without requiring Flutter app updates.

## Overview

The dynamic notification system allows you to:
- Send new types of notifications without updating the Flutter app
- Configure different actions (navigation, external URLs, custom actions)
- Maintain backward compatibility with existing notifications
- Add new routes and behaviors server-side

## Notification Payload Structure

### Basic Structure
```json
{
  "notification": {
    "title": "Your Title",
    "body": "Your message"
  },
  "data": {
    "action_type": "navigate|external_url|custom_action",
    // Additional fields based on action_type
  }
}
```

## Action Types

### 1. Navigation Actions (`action_type: "navigate"`)

Navigate to different screens within the app.

#### Simple Navigation
```json
{
  "notification": {
    "title": "Check your games!",
    "body": "New games are available"
  },
  "data": {
    "action_type": "navigate",
    "route_name": "/games"
  }
}
```

#### Navigation with Parameters
```json
{
  "notification": {
    "title": "Game Update",
    "body": "Your game has been updated"
  },
  "data": {
    "action_type": "navigate",
    "route_name": "/game_details",
    "route_params": {
      "gameId": "12345",
      "league": "39",
      "userId": "user123"
    },
    "clear_stack": true
  }
}
```

#### Navigation Without Clearing Stack (Shows Back Button)
```json
{
  "notification": {
    "title": "Game Update",
    "body": "Your game has been updated"
  },
  "data": {
    "action_type": "navigate",
    "route_name": "/game_details",
    "route_params": {
      "gameId": "12345",
      "league": "39",
      "userId": "user123"
    },
    "clear_stack": false
  }
}
```

#### Available Routes
- `/games` - Main games screen
- `/game_details` - Game details (with parameters)
- `/profile` - User profile
- `/leaderboard` - Leaderboard screen
- `/settings` - Settings screen
- `/table` - Table/standings screen
- Any custom route you add to your app

#### Navigation Stack Control
By default, notification navigation clears the navigation stack (no back button). You can control this behavior:

- `"clear_stack": true` (default) - Clears navigation stack, no back button
- `"clear_stack": false` - Preserves navigation stack, shows back button

### 2. External URL Actions (`action_type: "external_url"`)

Open external websites or deep links.

```json
{
  "notification": {
    "title": "Check out this link!",
    "body": "Important update available"
  },
  "data": {
    "action_type": "external_url",
    "url": "https://your-website.com/updates"
  }
}
```

### 3. Custom Actions (`action_type: "custom_action"`)

Execute custom behaviors within the app.

#### Show Dialog
```json
{
  "notification": {
    "title": "System Message",
    "body": "Tap to see details"
  },
  "data": {
    "action_type": "custom_action",
    "action_name": "show_dialog",
    "action_data": {
      "title": "Important Notice",
      "message": "Your subscription is expiring soon. Please renew to continue using all features."
    }
  }
}
```

#### Show Snackbar
```json
{
  "notification": {
    "title": "Quick Update",
    "body": "Tap for details"
  },
  "data": {
    "action_type": "custom_action",
    "action_name": "show_snackbar",
    "action_data": {
      "message": "Data has been refreshed successfully!",
      "duration": 5,
      "color": "0xFF4CAF50"
    }
  }
}
```

#### Refresh App Data
```json
{
  "notification": {
    "title": "Data Update",
    "body": "New data available"
  },
  "data": {
    "action_type": "custom_action",
    "action_name": "refresh_data",
    "action_data": {
      "refresh_type": "games",
      "league": "39"
    }
  }
}
```

## Backward Compatibility

Your existing notifications will continue to work. The system falls back to legacy handling when no `action_type` is specified:

### Legacy Format (Still Supported)
```json
{
  "notification": {
    "title": "Game Points",
    "body": "Check your points"
  },
  "data": {
    "screen": "game_points_details",
    "gameId": "12345",
    "league": "39",
    "userId": "user123"
  }
}
```

## Node.js Server Implementation

### Using Firebase Admin SDK

```javascript
const admin = require('firebase-admin');

// Initialize Firebase Admin (if not already done)
// admin.initializeApp({
//   credential: admin.credential.cert(serviceAccount)
// });

async function sendDynamicNotification(userToken, notificationConfig) {
  const message = {
    notification: {
      title: notificationConfig.title,
      body: notificationConfig.body
    },
    data: notificationConfig.data,
    token: userToken
  };

  try {
    const response = await admin.messaging().send(message);
    console.log('Successfully sent message:', response);
    return response;
  } catch (error) {
    console.log('Error sending message:', error);
    throw error;
  }
}

// Example usage
const examples = {
  // Navigate to games
  gameNavigation: {
    title: "New Games Available",
    body: "Check out the latest matches",
    data: {
      action_type: "navigate",
      route_name: "/games"
    }
  },

     // Game details with parameters (no back button)
   gameDetails: {
     title: "Game Update",
     body: "Your prediction results are in!",
     data: {
       action_type: "navigate",
       route_name: "/game_details",
       route_params: JSON.stringify({
         gameId: "12345",
         league: "39",
         userId: "user123"
       }),
       clear_stack: "true"
     }
   },

   // Game details with back button enabled
   gameDetailsWithBack: {
     title: "Game Update",
     body: "Your prediction results are in!",
     data: {
       action_type: "navigate",
       route_name: "/game_details",
       route_params: JSON.stringify({
         gameId: "12345",
         league: "39",
         userId: "user123"
       }),
       clear_stack: "false"
     }
   },

  // External URL
  externalLink: {
    title: "Visit Our Website",
    body: "Check out new features",
    data: {
      action_type: "external_url",
      url: "https://your-app-website.com"
    }
  },

  // Custom dialog
  customDialog: {
    title: "Important Notice",
    body: "Tap to see details",
    data: {
      action_type: "custom_action",
      action_name: "show_dialog",
      action_data: JSON.stringify({
        title: "Maintenance Notice",
        message: "The app will be under maintenance tonight from 2-4 AM."
      })
    }
  }
};

// Send to user
sendDynamicNotification(userToken, examples.gameNavigation);
```

### Express.js Route Example

```javascript
app.post('/send-notification', async (req, res) => {
  try {
    const { userToken, type, data } = req.body;
    
    let notificationConfig;
    
    switch(type) {
      case 'game_update':
        notificationConfig = {
          title: "Game Update",
          body: "Your game has new information",
          data: {
            action_type: "navigate",
            route_name: "/game_details",
            route_params: JSON.stringify(data.gameParams)
          }
        };
        break;
        
      case 'promotion':
        notificationConfig = {
          title: data.title,
          body: data.message,
          data: {
            action_type: "external_url",
            url: data.url
          }
        };
        break;
        
      case 'system_message':
        notificationConfig = {
          title: data.title,
          body: "Tap to view message",
          data: {
            action_type: "custom_action",
            action_name: "show_dialog",
            action_data: JSON.stringify({
              title: data.title,
              message: data.message
            })
          }
        };
        break;
        
      default:
        return res.status(400).json({ error: 'Unknown notification type' });
    }
    
    const response = await sendDynamicNotification(userToken, notificationConfig);
    res.json({ success: true, messageId: response });
    
  } catch (error) {
    console.error('Error sending notification:', error);
    res.status(500).json({ error: 'Failed to send notification' });
  }
});
```

## Adding New Custom Actions

To add new custom actions without updating the main notification service:

1. **Extend the `_handleCustomAction` method** in `firebase_messaging_service.dart`:

```dart
static Future<void> _handleCustomAction(Map<String, dynamic> data) async {
  final String? actionName = data['action_name'];
  final Map<String, dynamic>? actionData = data['action_data'] != null 
      ? Map<String, dynamic>.from(data['action_data']) 
      : null;

  switch (actionName) {
    case 'show_dialog':
      _showCustomDialog(actionData);
      break;
    case 'show_snackbar':
      _showCustomSnackbar(actionData);
      break;
    case 'refresh_data':
      _refreshAppData(actionData);
      break;
    // Add your new actions here
    case 'update_user_preferences':
      _updateUserPreferences(actionData);
      break;
    case 'trigger_sync':
      _triggerDataSync(actionData);
      break;
    default:
      print('Unknown custom action: $actionName');
      break;
  }
}
```

2. **Add the new action handlers**:

```dart
static void _updateUserPreferences(Map<String, dynamic>? data) {
  // Implementation for updating user preferences
}

static void _triggerDataSync(Map<String, dynamic>? data) {
  // Implementation for triggering data synchronization
}
```

## Testing

### Test with Firebase Console

1. Go to Firebase Console > Cloud Messaging
2. Create a new message
3. In the "Additional options" section, add custom data:

```
Key: action_type, Value: navigate
Key: route_name, Value: /games
```

### Test with curl

```bash
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=YOUR_SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "USER_FCM_TOKEN",
    "notification": {
      "title": "Test Navigation",
      "body": "Testing dynamic navigation"
    },
    "data": {
      "action_type": "navigate",
      "route_name": "/games"
    }
  }'
```

## Best Practices

1. **Always include fallback handling** for unknown action types
2. **Validate data** on both server and client sides
3. **Use meaningful action names** that describe what they do
4. **Test thoroughly** before sending to production users
5. **Keep payload size reasonable** (FCM has a 4KB limit)
6. **Log actions** for debugging and analytics

## Migration Guide

For existing notifications, no changes are required. The system automatically handles legacy format notifications. To migrate to the new system:

1. **Identify** current notification types
2. **Map** them to new action types
3. **Update** server code gradually
4. **Test** with small user groups first
5. **Monitor** for any issues

This system gives you the flexibility to add new notification behaviors without requiring app updates, while maintaining full backward compatibility with your existing notification system. 