import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('he')
  ];

  /// No description provided for @helloWorld.
  ///
  /// In en, this message translates to:
  /// **'hello'**
  String get helloWorld;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'add'**
  String get add;

  /// No description provided for @searchcustomer.
  ///
  /// In en, this message translates to:
  /// **'Search Customers'**
  String get searchcustomer;

  /// No description provided for @customers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customers;

  /// No description provided for @enteryourusername.
  ///
  /// In en, this message translates to:
  /// **'Enter your username'**
  String get enteryourusername;

  /// No description provided for @enteryourpassword.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get enteryourpassword;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'log in'**
  String get login;

  /// No description provided for @donthaveanaccount.
  ///
  /// In en, this message translates to:
  /// **'dont have an account?'**
  String get donthaveanaccount;

  /// No description provided for @allreadyhaveanaccount.
  ///
  /// In en, this message translates to:
  /// **'allready have an account?'**
  String get allreadyhaveanaccount;

  /// No description provided for @signup.
  ///
  /// In en, this message translates to:
  /// **'sign up'**
  String get signup;

  /// No description provided for @managment.
  ///
  /// In en, this message translates to:
  /// **'managment'**
  String get managment;

  /// No description provided for @employees.
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get employees;

  /// No description provided for @calls.
  ///
  /// In en, this message translates to:
  /// **'Calls'**
  String get calls;

  /// No description provided for @stuff.
  ///
  /// In en, this message translates to:
  /// **'team'**
  String get stuff;

  /// No description provided for @findcustomer.
  ///
  /// In en, this message translates to:
  /// **'find Customer'**
  String get findcustomer;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'log Out'**
  String get logout;

  /// No description provided for @addemployee.
  ///
  /// In en, this message translates to:
  /// **'add Employee'**
  String get addemployee;

  /// No description provided for @addcustomer.
  ///
  /// In en, this message translates to:
  /// **'add Customer'**
  String get addcustomer;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'name'**
  String get name;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'email address'**
  String get email;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'admin'**
  String get admin;

  /// No description provided for @choosPlayer.
  ///
  /// In en, this message translates to:
  /// **'choose player'**
  String get choosPlayer;

  /// No description provided for @department.
  ///
  /// In en, this message translates to:
  /// **'department'**
  String get department;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'address'**
  String get address;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'password'**
  String get password;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'cancel'**
  String get cancel;

  /// No description provided for @phonenumber.
  ///
  /// In en, this message translates to:
  /// **'phone'**
  String get phonenumber;

  /// No description provided for @calldetails.
  ///
  /// In en, this message translates to:
  /// **'Call Details'**
  String get calldetails;

  /// No description provided for @entercalldetails.
  ///
  /// In en, this message translates to:
  /// **'Enter call details'**
  String get entercalldetails;

  /// No description provided for @emergencycall.
  ///
  /// In en, this message translates to:
  /// **'Emergency Call'**
  String get emergencycall;

  /// No description provided for @savenewcall.
  ///
  /// In en, this message translates to:
  /// **'Open New Call'**
  String get savenewcall;

  /// No description provided for @saveeditcall.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveeditcall;

  /// No description provided for @newcall.
  ///
  /// In en, this message translates to:
  /// **'New Call for'**
  String get newcall;

  /// No description provided for @opens.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get opens;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @editcall.
  ///
  /// In en, this message translates to:
  /// **'Edit Call'**
  String get editcall;

  /// No description provided for @newcalls.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newcalls;

  /// No description provided for @waiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get waiting;

  /// No description provided for @managecalls.
  ///
  /// In en, this message translates to:
  /// **'manage calls'**
  String get managecalls;

  /// No description provided for @employeename.
  ///
  /// In en, this message translates to:
  /// **'employee name'**
  String get employeename;

  /// No description provided for @closecall.
  ///
  /// In en, this message translates to:
  /// **'Close Call'**
  String get closecall;

  /// No description provided for @adddetails.
  ///
  /// In en, this message translates to:
  /// **'Edit Call'**
  String get adddetails;

  /// No description provided for @assigncall.
  ///
  /// In en, this message translates to:
  /// **'Assign Call'**
  String get assigncall;

  /// No description provided for @callhistory.
  ///
  /// In en, this message translates to:
  /// **'Call History'**
  String get callhistory;

  /// No description provided for @enter.
  ///
  /// In en, this message translates to:
  /// **'Enter'**
  String get enter;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @attendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get attendance;

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get day;

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'hours'**
  String get hours;

  /// No description provided for @yourguess.
  ///
  /// In en, this message translates to:
  /// **'Your Guess'**
  String get yourguess;

  /// No description provided for @leavegroup.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave this group'**
  String get leavegroup;

  /// No description provided for @leavethegroup.
  ///
  /// In en, this message translates to:
  /// **'Leave Group'**
  String get leavethegroup;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'leave'**
  String get leave;

  /// No description provided for @createnewgroup.
  ///
  /// In en, this message translates to:
  /// **'Create New Group'**
  String get createnewgroup;

  /// No description provided for @entergroupname.
  ///
  /// In en, this message translates to:
  /// **'Enter group name'**
  String get entergroupname;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @mygroups.
  ///
  /// In en, this message translates to:
  /// **'My Groups'**
  String get mygroups;

  /// No description provided for @confirmsignout.
  ///
  /// In en, this message translates to:
  /// **'Confirm Signout'**
  String get confirmsignout;

  /// No description provided for @leaveapp.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out'**
  String get leaveapp;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'yes'**
  String get yes;

  /// No description provided for @signout.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signout;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @chooseallcompetitions.
  ///
  /// In en, this message translates to:
  /// **'Choose All Leagues'**
  String get chooseallcompetitions;

  /// No description provided for @joingrouptoseefreinds.
  ///
  /// In en, this message translates to:
  /// **'Join Group To See Freinds Guesses'**
  String get joingrouptoseefreinds;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'User Name'**
  String get username;

  /// No description provided for @guess.
  ///
  /// In en, this message translates to:
  /// **'Guess'**
  String get guess;

  /// No description provided for @sumpoints.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get sumpoints;

  /// No description provided for @noguessesfound.
  ///
  /// In en, this message translates to:
  /// **'No new or updated guesses to submit'**
  String get noguessesfound;

  /// No description provided for @savedsuccessfully.
  ///
  /// In en, this message translates to:
  /// **'saved successfully'**
  String get savedsuccessfully;

  /// No description provided for @thisleague.
  ///
  /// In en, this message translates to:
  /// **'This League'**
  String get thisleague;

  /// No description provided for @todayonly.
  ///
  /// In en, this message translates to:
  /// **'Today only'**
  String get todayonly;

  /// No description provided for @championsleague.
  ///
  /// In en, this message translates to:
  /// **'Champions League'**
  String get championsleague;

  /// No description provided for @ligathaal.
  ///
  /// In en, this message translates to:
  /// **'Ligat Haal'**
  String get ligathaal;

  /// No description provided for @europaleague.
  ///
  /// In en, this message translates to:
  /// **'Europa League'**
  String get europaleague;

  /// No description provided for @clubworldcup.
  ///
  /// In en, this message translates to:
  /// **'Club World Cup'**
  String get clubworldcup;

  /// No description provided for @laliga.
  ///
  /// In en, this message translates to:
  /// **'La Liga'**
  String get laliga;

  /// No description provided for @bundesleague.
  ///
  /// In en, this message translates to:
  /// **'bundes League'**
  String get bundesleague;

  /// No description provided for @premierleague.
  ///
  /// In en, this message translates to:
  /// **'premier League'**
  String get premierleague;

  /// No description provided for @conferenceleague.
  ///
  /// In en, this message translates to:
  /// **'conference League'**
  String get conferenceleague;

  /// No description provided for @nogames.
  ///
  /// In en, this message translates to:
  /// **'No games'**
  String get nogames;

  /// No description provided for @invitefriend.
  ///
  /// In en, this message translates to:
  /// **'Invite Friend'**
  String get invitefriend;

  /// No description provided for @invitecodecopy.
  ///
  /// In en, this message translates to:
  /// **'Invite code copied to clipboard:'**
  String get invitecodecopy;

  /// No description provided for @shareinvitecode.
  ///
  /// In en, this message translates to:
  /// **'Share this code with your friend to invite them to the group.'**
  String get shareinvitecode;

  /// No description provided for @joingroup.
  ///
  /// In en, this message translates to:
  /// **'Join Group'**
  String get joingroup;

  /// No description provided for @enterinvitecode.
  ///
  /// In en, this message translates to:
  /// **'Enter invite code'**
  String get enterinvitecode;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @table.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get table;

  /// No description provided for @daypoints.
  ///
  /// In en, this message translates to:
  /// **'daily points'**
  String get daypoints;

  /// No description provided for @createpassword.
  ///
  /// In en, this message translates to:
  /// **'Create password'**
  String get createpassword;

  /// No description provided for @loginfailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get loginfailed;

  /// No description provided for @registrationfailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed'**
  String get registrationfailed;

  /// No description provided for @registrationsuccessful.
  ///
  /// In en, this message translates to:
  /// **'Registration successful'**
  String get registrationsuccessful;

  /// No description provided for @forgotpassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotpassword;

  /// No description provided for @emailsent.
  ///
  /// In en, this message translates to:
  /// **'Email Sent'**
  String get emailsent;

  /// No description provided for @emailsentlink.
  ///
  /// In en, this message translates to:
  /// **'A link has been sent to your email account. This link will be valid for 3 minutes only.'**
  String get emailsentlink;

  /// No description provided for @choosewinner.
  ///
  /// In en, this message translates to:
  /// **'Choose Winner'**
  String get choosewinner;

  /// No description provided for @teamcannotbechanged.
  ///
  /// In en, this message translates to:
  /// **'Note: You can change your selection up to one hour before the first match'**
  String get teamcannotbechanged;

  /// No description provided for @saveteam.
  ///
  /// In en, this message translates to:
  /// **'Save Team'**
  String get saveteam;

  /// No description provided for @savePlayer.
  ///
  /// In en, this message translates to:
  /// **'Save  Player'**
  String get savePlayer;

  /// No description provided for @topScorers.
  ///
  /// In en, this message translates to:
  /// **'Top Scorers'**
  String get topScorers;

  /// No description provided for @chooseteam.
  ///
  /// In en, this message translates to:
  /// **'Choose Team'**
  String get chooseteam;

  /// No description provided for @yourwinner.
  ///
  /// In en, this message translates to:
  /// **'Your Winner'**
  String get yourwinner;

  /// No description provided for @chooseTopScorer.
  ///
  /// In en, this message translates to:
  /// **'choose Top scorer '**
  String get chooseTopScorer;

  /// No description provided for @selectleaguefirst.
  ///
  /// In en, this message translates to:
  /// **'Select league first'**
  String get selectleaguefirst;

  /// No description provided for @taptoselectwinner.
  ///
  /// In en, this message translates to:
  /// **'Tap to select winner'**
  String get taptoselectwinner;

  /// No description provided for @taptoselecttopscorer.
  ///
  /// In en, this message translates to:
  /// **'Tap to select top scorer'**
  String get taptoselecttopscorer;

  /// No description provided for @selectionnotavailableyet.
  ///
  /// In en, this message translates to:
  /// **'Selection not available yet'**
  String get selectionnotavailableyet;

  /// No description provided for @selectiontimeexpired.
  ///
  /// In en, this message translates to:
  /// **'Selection time expired'**
  String get selectiontimeexpired;

  /// No description provided for @selectionnotavailable.
  ///
  /// In en, this message translates to:
  /// **'Selection not available'**
  String get selectionnotavailable;

  /// No description provided for @yourwinners.
  ///
  /// In en, this message translates to:
  /// **'your winners'**
  String get yourwinners;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// No description provided for @signinwithgoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign In with Google'**
  String get signinwithgoogle;

  /// No description provided for @results.
  ///
  /// In en, this message translates to:
  /// **'results'**
  String get results;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'profile'**
  String get profile;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'preferences'**
  String get preferences;

  /// No description provided for @updateavailable.
  ///
  /// In en, this message translates to:
  /// **'Update Available'**
  String get updateavailable;

  /// No description provided for @askforupdate.
  ///
  /// In en, this message translates to:
  /// **'A new version of the app is available. Would you like to update?'**
  String get askforupdate;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @allleagus.
  ///
  /// In en, this message translates to:
  /// **'All Leagus'**
  String get allleagus;

  /// No description provided for @cleardate.
  ///
  /// In en, this message translates to:
  /// **'Clear date'**
  String get cleardate;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @totalGuesses.
  ///
  /// In en, this message translates to:
  /// **'Total Guesses'**
  String get totalGuesses;

  /// No description provided for @directGuesses.
  ///
  /// In en, this message translates to:
  /// **'Direct Guesses'**
  String get directGuesses;

  /// No description provided for @directionGuesses.
  ///
  /// In en, this message translates to:
  /// **'Direction Guesses'**
  String get directionGuesses;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'send'**
  String get send;

  /// No description provided for @chooseleagues.
  ///
  /// In en, this message translates to:
  /// **'my Leagues'**
  String get chooseleagues;

  /// No description provided for @managegroups.
  ///
  /// In en, this message translates to:
  /// **'Manage your groups and competitions'**
  String get managegroups;

  /// No description provided for @winningpredictions.
  ///
  /// In en, this message translates to:
  /// **'Your winning predictions'**
  String get winningpredictions;

  /// No description provided for @yourprediction.
  ///
  /// In en, this message translates to:
  /// **'Your prediction'**
  String get yourprediction;

  /// No description provided for @noEnabledLeagues.
  ///
  /// In en, this message translates to:
  /// **'No leagues available for notifications'**
  String get noEnabledLeagues;

  /// No description provided for @enableLeaguesFirst.
  ///
  /// In en, this message translates to:
  /// **'Please enable leagues in the Chosen Leagues tab first'**
  String get enableLeaguesFirst;

  /// No description provided for @goToChosenLeagues.
  ///
  /// In en, this message translates to:
  /// **'Go to Chosen Leagues'**
  String get goToChosenLeagues;

  /// No description provided for @nolivegames.
  ///
  /// In en, this message translates to:
  /// **'No live games right now'**
  String get nolivegames;

  /// No description provided for @cleardatefilter.
  ///
  /// In en, this message translates to:
  /// **'clear'**
  String get cleardatefilter;

  /// No description provided for @nogroupsyet.
  ///
  /// In en, this message translates to:
  /// **'No groups yet'**
  String get nogroupsyet;

  /// No description provided for @points.
  ///
  /// In en, this message translates to:
  /// **'points'**
  String get points;

  /// No description provided for @pst.
  ///
  /// In en, this message translates to:
  /// **'pst'**
  String get pst;

  /// No description provided for @topScorerPoints.
  ///
  /// In en, this message translates to:
  /// **'goals Points:'**
  String get topScorerPoints;

  /// No description provided for @noTopScorersYet.
  ///
  /// In en, this message translates to:
  /// **'No top scorers yet'**
  String get noTopScorersYet;

  /// No description provided for @noWinnersYet.
  ///
  /// In en, this message translates to:
  /// **'No winners yet'**
  String get noWinnersYet;

  /// No description provided for @allCompetitions.
  ///
  /// In en, this message translates to:
  /// **'All Competitions'**
  String get allCompetitions;

  /// No description provided for @provideEmail.
  ///
  /// In en, this message translates to:
  /// **'please provide an email address'**
  String get provideEmail;

  /// No description provided for @teamSavedsuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Team saved successfully'**
  String get teamSavedsuccessfully;

  /// No description provided for @failedtoSaveTeam.
  ///
  /// In en, this message translates to:
  /// **'Failed to save team'**
  String get failedtoSaveTeam;

  /// No description provided for @errorsavingteam.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while saving the team'**
  String get errorsavingteam;

  /// No description provided for @pleaseSelectTeamFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select a team first'**
  String get pleaseSelectTeamFirst;

  /// No description provided for @playerSavedsuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Player saved successfully'**
  String get playerSavedsuccessfully;

  /// No description provided for @failedtoSaveplayer.
  ///
  /// In en, this message translates to:
  /// **'Failed to save Player'**
  String get failedtoSaveplayer;

  /// No description provided for @errorsavingplayer.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while saving the player'**
  String get errorsavingplayer;

  /// No description provided for @pleaseSelectplayerFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select a player first'**
  String get pleaseSelectplayerFirst;

  /// No description provided for @monday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monday;

  /// No description provided for @tuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get tuesday;

  /// No description provided for @wednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get wednesday;

  /// No description provided for @thursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get thursday;

  /// No description provided for @friday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get friday;

  /// No description provided for @saturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get saturday;

  /// No description provided for @sunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunday;

  /// No description provided for @january_short.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get january_short;

  /// No description provided for @february_short.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get february_short;

  /// No description provided for @march_short.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get march_short;

  /// No description provided for @april_short.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get april_short;

  /// No description provided for @may_short.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get may_short;

  /// No description provided for @june_short.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get june_short;

  /// No description provided for @july_short.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get july_short;

  /// No description provided for @august_short.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get august_short;

  /// No description provided for @september_short.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get september_short;

  /// No description provided for @october_short.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get october_short;

  /// No description provided for @november_short.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get november_short;

  /// No description provided for @december_short.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get december_short;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteaccountconfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account? This action cannot be undone.'**
  String get deleteaccountconfirm;

  /// No description provided for @deleteaccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteaccount;

  /// No description provided for @userdetails.
  ///
  /// In en, this message translates to:
  /// **'User Details'**
  String get userdetails;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted successfully'**
  String get accountDeleted;

  /// No description provided for @matchEvents.
  ///
  /// In en, this message translates to:
  /// **'Match Events'**
  String get matchEvents;

  /// No description provided for @loadingEvents.
  ///
  /// In en, this message translates to:
  /// **'Loading events...'**
  String get loadingEvents;

  /// No description provided for @failedToLoadEvents.
  ///
  /// In en, this message translates to:
  /// **'Failed to load events'**
  String get failedToLoadEvents;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @noGoals.
  ///
  /// In en, this message translates to:
  /// **'No goals scored yet'**
  String get noGoals;

  /// No description provided for @eventsAppear.
  ///
  /// In en, this message translates to:
  /// **'Events will appear here when goals are scored'**
  String get eventsAppear;

  /// No description provided for @goals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get goals;

  /// No description provided for @assist.
  ///
  /// In en, this message translates to:
  /// **'Assist:'**
  String get assist;

  /// No description provided for @noGuesses.
  ///
  /// In en, this message translates to:
  /// **'No guesses'**
  String get noGuesses;

  /// No description provided for @finishAfterExtraTime.
  ///
  /// In en, this message translates to:
  /// **'Finished After ET'**
  String get finishAfterExtraTime;

  /// No description provided for @extraTime.
  ///
  /// In en, this message translates to:
  /// **'Extra Time'**
  String get extraTime;

  /// No description provided for @firstHalf.
  ///
  /// In en, this message translates to:
  /// **'First Half'**
  String get firstHalf;

  /// No description provided for @secondHalf.
  ///
  /// In en, this message translates to:
  /// **'Second Half'**
  String get secondHalf;

  /// No description provided for @halftime.
  ///
  /// In en, this message translates to:
  /// **'Halftime'**
  String get halftime;

  /// No description provided for @notStarted.
  ///
  /// In en, this message translates to:
  /// **'Not Started'**
  String get notStarted;

  /// No description provided for @finished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get finished;

  /// No description provided for @postponed.
  ///
  /// In en, this message translates to:
  /// **'Postponed'**
  String get postponed;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to the ScoreCast App!'**
  String get welcomeTitle;

  /// No description provided for @welcomeContent.
  ///
  /// In en, this message translates to:
  /// **'An innovative sports prediction app that lets you guess game results, compete with friends, and earn points. Start your journey toward an exciting competition!'**
  String get welcomeContent;

  /// No description provided for @guessTitle.
  ///
  /// In en, this message translates to:
  /// **'Guess Results'**
  String get guessTitle;

  /// No description provided for @guessContent.
  ///
  /// In en, this message translates to:
  /// **'Pick an outcome for each match from your chosen tournaments. You can guess the general direction (win/draw) or the exact score.'**
  String get guessContent;

  /// No description provided for @scoringTitle.
  ///
  /// In en, this message translates to:
  /// **'Scoring System'**
  String get scoringTitle;

  /// No description provided for @scoringContent.
  ///
  /// In en, this message translates to:
  /// **'Correct direction = Points based on betting odds.\nExact score = Bonus of 4 points.'**
  String get scoringContent;

  /// No description provided for @groupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Groups & Competitions'**
  String get groupsTitle;

  /// No description provided for @groupsContent.
  ///
  /// In en, this message translates to:
  /// **'Create or join a group via invite link. Compete with friends by collecting points.'**
  String get groupsContent;

  /// No description provided for @winnerTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Winning Team'**
  String get winnerTitle;

  /// No description provided for @winnerContent.
  ///
  /// In en, this message translates to:
  /// **'Choose one team to win the tournament. If you’re right, you’ll earn a 20-point bonus.'**
  String get winnerContent;

  /// No description provided for @topScorerTitle.
  ///
  /// In en, this message translates to:
  /// **'Top Scorer'**
  String get topScorerTitle;

  /// No description provided for @topScorerContent.
  ///
  /// In en, this message translates to:
  /// **'Pick one player for the tournament. You’ll earn 2 bonus points for every goal they score.'**
  String get topScorerContent;

  /// No description provided for @guessDeadlineTitle.
  ///
  /// In en, this message translates to:
  /// **'Guess Deadline'**
  String get guessDeadlineTitle;

  /// No description provided for @guessDeadlineContent.
  ///
  /// In en, this message translates to:
  /// **'You can choose match results until the moment each match kicks off. The tournament winner and top scorer selections can be made up to one hour before the league\'s opening match! Once a match starts, the selections are locked and cannot be changed'**
  String get guessDeadlineContent;

  /// No description provided for @importantNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Important Note'**
  String get importantNoteTitle;

  /// No description provided for @importantNoteContent.
  ///
  /// In en, this message translates to:
  /// **'Guesses cannot be changed after the game starts. Make sure to review them beforehand.'**
  String get importantNoteContent;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'settings'**
  String get settings;

  /// No description provided for @settings_account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settings_account;

  /// No description provided for @settings_rules.
  ///
  /// In en, this message translates to:
  /// **'Game Rules'**
  String get settings_rules;

  /// No description provided for @settings_language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settings_language;

  /// No description provided for @settings_eng.
  ///
  /// In en, this message translates to:
  /// **'ENG'**
  String get settings_eng;

  /// No description provided for @settings_heb.
  ///
  /// In en, this message translates to:
  /// **'HEB'**
  String get settings_heb;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'from'**
  String get from;

  /// No description provided for @settings_theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settings_theme;

  /// No description provided for @privategroups.
  ///
  /// In en, this message translates to:
  /// **'Private Group'**
  String get privategroups;

  /// No description provided for @publicgroups.
  ///
  /// In en, this message translates to:
  /// **'Public Groups'**
  String get publicgroups;

  /// No description provided for @groupnamealreadyexists.
  ///
  /// In en, this message translates to:
  /// **'Group name already exists'**
  String get groupnamealreadyexists;

  /// No description provided for @groupcreatedsuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Group created successfully'**
  String get groupcreatedsuccessfully;

  /// No description provided for @nogroupsfound.
  ///
  /// In en, this message translates to:
  /// **'No Groups Found'**
  String get nogroupsfound;

  /// No description provided for @nogroupsmessage.
  ///
  /// In en, this message translates to:
  /// **'You are not a member of any private groups yet. Join or create a group to start competing!'**
  String get nogroupsmessage;

  /// No description provided for @notmemberanygroup.
  ///
  /// In en, this message translates to:
  /// **'You are not a member of any group'**
  String get notmemberanygroup;

  /// No description provided for @numberOfGames.
  ///
  /// In en, this message translates to:
  /// **'games'**
  String get numberOfGames;

  /// No description provided for @chooseCompetitions.
  ///
  /// In en, this message translates to:
  /// **'Choose your competitions'**
  String get chooseCompetitions;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'he': return AppLocalizationsHe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
