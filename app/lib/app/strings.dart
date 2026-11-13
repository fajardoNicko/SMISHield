import '../data/accounts.dart';
import '../ml/explanations.dart';

/// Screen text in English and Filipino. Analysis wording (labels, warning
/// signs, advice) is in ml/explanations.dart.
class Strings {
  const Strings(this.language);

  final AppLanguage language;

  bool get isFilipino => language == AppLanguage.filipino;

  String _t(String english, String filipino) => isFilipino ? filipino : english;

  static const _monthsEnglish = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', //
    'August', 'September', 'October', 'November', 'December',
  ];
  static const _monthsFilipino = [
    'Enero', 'Pebrero', 'Marso', 'Abril', 'Mayo', 'Hunyo', 'Hulyo', //
    'Agosto', 'Setyembre', 'Oktubre', 'Nobyembre', 'Disyembre',
  ];

  /// "July 18, 2026"
  String date(DateTime d) =>
      '${(isFilipino ? _monthsFilipino : _monthsEnglish)[d.month - 1]} ${d.day}, ${d.year}';

  /// "2:30 PM"
  String time(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  // Brand
  String get appName => 'SMISHield';
  String get tagline => _t(
    'SHIELD YOURSELF FROM SMS PHISHING',
    'PROTEKTAHAN ANG IYONG SARILI LABAN SA SMS PHISHING',
  );

  // Log in / sign up
  String get login => _t('Login', 'Mag-login');
  String get signUp => _t('Sign up', 'Mag-sign up');
  String get emailLabel => 'Email';
  String get emailHint => _t('Insert email', 'Ilagay ang email');
  String get passwordLabel => 'Password';
  String get passwordHint => _t('Insert password', 'Ilagay ang password');
  String get fullNameLabel => _t('Full name', 'Buong pangalan');
  String get fullNameHint =>
      _t('Insert your full name', 'Ilagay ang iyong buong pangalan');
  String get passwordRule => _t(
    'At least $minPasswordLength characters',
    'Hindi bababa sa $minPasswordLength na character',
  );
  String get showPassword => _t('Show password', 'Ipakita ang password');
  String get hidePassword => _t('Hide password', 'Itago ang password');
  String get forgotPassword =>
      _t('Forgot password?', 'Nakalimutan ang password?');
  String get newUser => _t('Are you a new user?', 'Bago ka ba rito?');
  String get alreadyUser => _t('Already a user?', 'May account ka na?');
  String get localAccountNote => _t(
    'Your account is saved on this phone only.',
    'Sa phone na ito lang naka-save ang iyong account.',
  );

  String authError(AuthError error) => switch (error) {
    AuthError.nameRequired => _t(
      'Please enter your full name.',
      'Ilagay ang iyong buong pangalan.',
    ),
    AuthError.invalidEmail => _t(
      'Please enter a valid email address.',
      'Maglagay ng wastong email address.',
    ),
    AuthError.weakPassword => _t(
      'Use a password with at least $minPasswordLength characters.',
      'Gumamit ng password na may hindi bababa sa $minPasswordLength na character.',
    ),
    AuthError.emailTaken => _t(
      'An account with this email already exists on this phone. Log in instead.',
      'May account na sa phone na ito gamit ang email na ito. Mag-login na lang.',
    ),
    AuthError.wrongCredentials => _t(
      'Incorrect email or password.',
      'Mali ang email o password.',
    ),
    AuthError.wrongRecoveryCode => _t(
      'The email or recovery code is incorrect.',
      'Mali ang email o recovery code.',
    ),
  };

  // Recovery code and password reset
  String get recoveryTitle =>
      _t('Save your recovery code', 'I-save ang iyong recovery code');
  String get recoveryBody => _t(
    'Your account is stored only on this phone, so a password cannot be reset by email. '
        'If you forget your password, you will need this code. Write it down or take a screenshot.',
    'Sa phone na ito lang naka-save ang iyong account kaya hindi mare-reset ang password sa email. '
        'Kapag nakalimutan mo ang password, kakailanganin mo ang code na ito. Isulat ito o i-screenshot.',
  );
  String get recoverySaved => _t('I saved it', 'Na-save ko na');
  String get resetTitle => _t('Reset password', 'I-reset ang password');
  String get resetIntro => _t(
    'Enter your email and the recovery code you got when you signed up.',
    'Ilagay ang iyong email at ang recovery code na natanggap mo noong nag-sign up ka.',
  );
  String get recoveryCodeLabel => 'Recovery code';
  String get recoveryCodeHint => 'XXXX-XXXX';
  String get newPasswordLabel => _t('New password', 'Bagong password');
  String get resetButton => _t('Reset password', 'I-reset ang password');
  String get resetDoneTitle =>
      _t('Password changed', 'Napalitan na ang password');
  String get resetDoneBody => _t(
    'You can now log in with your new password. Your old recovery code no longer works; here is your new one:',
    'Maaari ka nang mag-login gamit ang bagong password. Hindi na gagana ang lumang recovery code; ito ang bago:',
  );

  // Navigation
  String get home => 'Home';
  String get history => 'History';
  String get tips => _t('Tips', 'Mga Tip');
  String get profile => 'Profile';
  String get menu => 'Menu';
  String get back => _t('Back', 'Bumalik');

  // Home
  String get homeIntro => _t(
    'Paste any SMS message below and let SMISHield check it for potential risks.',
    'I-paste ang anumang SMS na mensahe sa ibaba at hayaang suriin ito ng SMISHield upang matukoy ang mga posibleng panganib.',
  );
  String get pasteHere =>
      _t('Paste your message here', 'I-paste ang iyong mensahe dito');
  String get inputHint => _t(
    'Paste SMS message that you want to check ...',
    'I-paste ang SMS na gusto mong suriin ...',
  );
  String get paste => _t('Paste', 'I-paste');
  String get clear => _t('Clear', 'Burahin');
  String get analyze => _t('Analyze Message', 'Suriin ang Mensahe');
  String get analyzing => _t('Analyzing message...', 'Sinusuri ang mensahe...');
  String get clipboardEmpty =>
      _t('The clipboard has no text.', 'Walang text sa clipboard.');
  String get howItWorks => _t('How it works', 'Paano ito gumagana');
  String get stepPaste => _t('Paste SMS', 'I-paste ang SMS');
  String get stepAnalyze => _t('Analyze', 'Suriin');
  String get stepResult => _t('Get Result', 'Kunin ang Resulta');

  // Result
  String get resultTitle => _t('Analysis Result', 'Resulta ng Pagsusuri');
  String get messageAnalyzed => _t('Message Analyzed', 'Sinuring Mensahe');
  String get staySafe => _t('Stay Safe!', 'Mag-ingat!');
  String get checkAnother =>
      _t('Check another message', 'Sumuri ng ibang mensahe');

  /// Capped at 99%: the model is never certain.
  String confidence(double p) {
    final percent = (p * 100).round().clamp(1, 99);
    return _t('Model confidence: $percent%', 'Katiyakan ng model: $percent%');
  }

  String get highlightLegend => _t(
    'Highlighted: warning signs and words the model weighed most.',
    'Naka-highlight: mga babala at mga salitang pinakatinimbang ng model.',
  );
  String get previewNote => _t(
    'Preview version: the model is still being trained, so some results may be wrong.',
    'Preview na bersyon: sinasanay pa ang model kaya maaaring mali ang ilang resulta.',
  );

  // History
  String get historyEmpty => _t(
    'No analyzed messages yet. Results you check will appear here.',
    'Wala pang nasuring mensahe. Dito lalabas ang mga resulta ng iyong pagsusuri.',
  );
  String get historyPrivacy => _t(
    'History is saved on your device only and is never shared',
    'Sa iyong device lang naka-save ang history at hindi ito ibinabahagi',
  );
  String get delete => _t('Delete', 'Burahin');
  String get entryDeleted => _t('Removed from history', 'Inalis sa history');

  // Tips
  String get tipsTitle =>
      _t('How to stay safe from smishing?', 'Paano makaiwas sa smishing?');
  List<(String, String)> get tipItems => [
    (
      _t(
        "Don't click suspicious links",
        'Huwag i-click ang kahina-hinalang link',
      ),
      _t(
        'Avoid clicking links from unknown senders or unexpected messages.',
        'Iwasang i-click ang mga link mula sa hindi kilalang nagpadala o hindi inaasahang mensahe.',
      ),
    ),
    (
      _t(
        'Never share personal info',
        'Huwag ibigay ang personal na impormasyon',
      ),
      _t(
        'Banks or legit companies will never ask for passwords or OTPs via SMS.',
        'Hindi kailanman hihingi ng password o OTP sa SMS ang mga bangko o lehitimong kumpanya.',
      ),
    ),
    (
      _t('Watch out for urgency', 'Mag-ingat sa pagmamadali'),
      _t(
        'Messages that create panic or urgency are often scams.',
        'Kadalasang scam ang mga mensaheng nagdudulot ng takot o pagmamadali.',
      ),
    ),
    (
      _t('Verify the sender', 'I-verify ang nagpadala'),
      _t(
        'Contact the company directly using official contact details.',
        'Direktang kontakin ang kumpanya gamit ang kanilang opisyal na contact details.',
      ),
    ),
  ];
  String get tipsFooter => _t(
    'Think before you tap. Protect what matters.',
    'Mag-isip bago mag-tap. Protektahan ang mahalaga.',
  );

  // Profile
  String memberSince(String date) =>
      _t('Member since: $date', 'Miyembro mula: $date');
  String get messagesAnalyzed =>
      _t('Messages Analyzed', 'Mga Nasuring Mensahe');
  String get logOut => _t('Log Out', 'Mag-log out');

  // Menu
  String get about => _t('About SMISHield', 'Tungkol sa SMISHield');
  String get aboutText => _t(
    'SMISHield is an Android-based cybersecurity application designed to detect potential '
        'smishing (SMS phishing) attacks in Filipino and Taglish text messages. Powered by machine '
        'learning and text analysis, it evaluates messages and classifies them as Safe, Suspicious, '
        'or High Risk. By allowing users to manually submit messages for analysis, SMISHield '
        'prioritizes privacy while helping users stay protected from scams, phishing attempts, and '
        'fraudulent SMS threats.',
    'Ang SMISHield ay isang Android application para sa cybersecurity na tumutukoy ng posibleng '
        'smishing (SMS phishing) sa mga text message na nasa Filipino at Taglish. Gamit ang machine '
        'learning at pagsusuri ng teksto, sinusuri nito ang mga mensahe at inuuri bilang Ligtas, '
        'Kahina-hinala, o Mapanganib. Dahil ikaw mismo ang nagpapasa ng mensaheng susuriin, '
        'inuuna ng SMISHield ang iyong privacy habang tinutulungan kang maprotektahan laban sa '
        'scam, phishing, at mapanlinlang na SMS.',
  );
  String modelInfo(int messages, bool isFinal, {int synthetic = 0}) {
    final status = isFinal
        ? ''
        : _t(
            ' (interim labels, still being finalized)',
            ' (pansamantalang label, tinatapos pa)',
          );
    final extra = synthetic == 0
        ? ''
        : _t(
            ' plus $synthetic synthetic messages',
            ' at $synthetic synthetic na mensahe',
          );
    return _t(
      'Model: TF-IDF + Multinomial Naive Bayes, trained on $messages real labelled messages$extra$status.',
      'Model: TF-IDF + Multinomial Naive Bayes, sinanay sa $messages totoong mensaheng may label$extra$status.',
    );
  }

  String get versionInfo =>
      _t('Version 0.3.1 (preview)', 'Bersyon 0.3.1 (preview)');
  String get darkModeLabel => 'Dark Mode';
  String get darkModeText => _t(
    'Reduce screen glare and improve viewing comfort in low-light environments.',
    'Bawasan ang silaw ng screen at gawing mas komportable ang pagtingin sa madilim na lugar.',
  );
  String get languageLabel => _t('Language (English)', 'Wika (Filipino)');
  String get languageText => _t(
    'Choose your preferred language for the application.',
    'Piliin ang gusto mong wika para sa application.',
  );
  String get privacy => _t('Privacy and Policy', 'Patakaran sa Pagkapribado');
  String get privacyText => _t(
    'Read how SMISHield collects, uses, and protects your information.',
    'Basahin kung paano kinokolekta, ginagamit, at pinoprotektahan ng SMISHield ang iyong impormasyon.',
  );
  String get viewPolicy => _t('View Policy', 'Tingnan ang Patakaran');
  String get terms => _t('Terms and Condition', 'Mga Tuntunin at Kundisyon');
  String get termsText => _t(
    'Review the rules, responsibilities, and conditions for using SMISHield.',
    'Suriin ang mga patakaran, responsibilidad, at kundisyon sa paggamit ng SMISHield.',
  );
  String get viewTerms => _t('View Terms', 'Tingnan ang Tuntunin');
  String get clearHistoryLabel =>
      _t('Clear Analysis History', 'Burahin ang History');
  String get clearHistoryText => _t(
    'Delete all saved analysis records.',
    'Burahin ang lahat ng naka-save na resulta ng pagsusuri.',
  );
  String get clearHistoryButton => _t('Clear History', 'Burahin ang History');
  String get clearConfirmTitle =>
      _t('Clear all history?', 'Burahin ang buong history?');
  String clearConfirmBody(int n) => _t(
    'This deletes all $n saved analyses on this phone. It cannot be undone.',
    'Buburahin nito ang lahat ng $n na naka-save na pagsusuri sa phone na ito. Hindi na ito maibabalik.',
  );
  String get cancel => _t('Cancel', 'Kanselahin');
  String get historyCleared => _t('History cleared', 'Nabura na ang history');
  String get historyAlreadyEmpty =>
      _t('There is no history to clear.', 'Walang history na buburahin.');

  // Policy documents: (heading, body) pairs.
  List<(String, String)> get privacyPolicy => [
    (
      _t('Summary', 'Buod'),
      _t(
        'SMISHield works entirely on your phone. It does not connect to the internet, does not '
            'read your SMS inbox, and does not send your messages or account details to anyone.',
        'Gumagana ang SMISHield sa iyong phone lamang. Hindi ito kumokonekta sa internet, hindi '
            'nito binabasa ang iyong SMS inbox, at hindi nito ipinapadala kanino man ang iyong mga '
            'mensahe o detalye ng account.',
      ),
    ),
    (
      _t('What is stored', 'Ano ang iniimbak'),
      _t(
        'Your full name and email (to identify your local account); your password and recovery '
            'code only in protected (hashed) form; the messages you choose to analyze with their '
            'result, date and time; and your settings (dark mode and language).',
        'Ang iyong buong pangalan at email (para makilala ang iyong account sa phone); ang iyong '
            'password at recovery code sa protektadong (hashed) anyo lamang; ang mga mensaheng '
            'pinili mong suriin kasama ang resulta, petsa at oras; at ang iyong settings (dark mode '
            'at wika).',
      ),
    ),
    (
      _t('How it is used', 'Paano ito ginagamit'),
      _t(
        'Only to analyze the messages you paste, to show your history and profile statistics, '
            'and to keep your preferences. Each account sees only its own history.',
        'Para lamang suriin ang mga mensaheng iyong i-paste, ipakita ang iyong history at '
            'statistics sa profile, at tandaan ang iyong mga setting. Sariling history lang ang '
            'nakikita ng bawat account.',
      ),
    ),
    (
      _t('Permissions', 'Mga pahintulot'),
      _t(
        'The app asks for no special permissions: no SMS, contacts, location, or internet access. '
            'Messages reach the app only when you paste them yourself.',
        'Walang espesyal na pahintulot na hinihingi ang app: walang SMS, contacts, location, o '
            'internet. Napupunta lamang ang mensahe sa app kapag ikaw mismo ang nag-paste nito.',
      ),
    ),
    (
      _t('Your control', 'Ang iyong kontrol'),
      _t(
        'You can delete single history entries or clear all history from the menu. Uninstalling '
            'the app deletes all of its data from the phone.',
        'Maaari mong burahin ang isang entry o ang buong history mula sa menu. Kapag in-uninstall '
            'ang app, mabubura ang lahat ng data nito sa phone.',
      ),
    ),
    (
      _t('Data Privacy Act', 'Data Privacy Act'),
      _t(
        'SMISHield is a student research project of the Valenzuela City School of Mathematics and '
            'Science. It is designed in line with the Data Privacy Act of 2012 (Republic Act No. '
            '10173): it collects only what it needs and keeps it on your device. Avoid pasting '
            'messages that contain other people\'s private information.',
        'Ang SMISHield ay isang pananaliksik ng mga mag-aaral ng Valenzuela City School of '
            'Mathematics and Science. Idinisenyo ito alinsunod sa Data Privacy Act of 2012 (Republic '
            'Act No. 10173): kinukuha lamang nito ang kailangan at sa iyong device lang ito iniimbak. '
            'Iwasang mag-paste ng mensaheng may pribadong impormasyon ng ibang tao.',
      ),
    ),
  ];

  List<(String, String)> get termsAndConditions => [
    (
      _t('Purpose', 'Layunin'),
      _t(
        'SMISHield helps you judge whether a text message may be smishing. It is an educational '
            'and research tool developed by students of the Valenzuela City School of Mathematics '
            'and Science.',
        'Tinutulungan ka ng SMISHield na matukoy kung maaaring smishing ang isang text message. '
            'Isa itong kasangkapan para sa edukasyon at pananaliksik na binuo ng mga mag-aaral ng '
            'Valenzuela City School of Mathematics and Science.',
      ),
    ),
    (
      _t('Results are guidance', 'Gabay lamang ang resulta'),
      _t(
        'Each result is an estimate made by a machine-learning model and can be wrong. A "Safe" '
            'result does not guarantee that a message is harmless. When in doubt, contact the '
            'company or person through official channels before acting.',
        'Ang bawat resulta ay tantiya ng isang machine-learning model at maaaring mali. Hindi '
            'garantiya ng resultang "Ligtas" na walang panganib ang mensahe. Kapag may duda, '
            'kontakin muna ang kumpanya o tao sa opisyal na paraan bago kumilos.',
      ),
    ),
    (
      _t('Your responsibilities', 'Ang iyong mga responsibilidad'),
      _t(
        'Keep your password and recovery code private, paste only messages you are allowed to '
            'share, and do not use the app to create, test, or improve scam messages.',
        'Panatilihing pribado ang iyong password at recovery code, mag-paste lamang ng mensaheng '
            'pinapayagan kang ibahagi, at huwag gamitin ang app para gumawa, sumubok, o pagandahin '
            'ang mga scam na mensahe.',
      ),
    ),
    (
      _t('Accounts', 'Mga account'),
      _t(
        'Accounts exist only on the phone where they were created. They cannot be recovered '
            'without the recovery code, and they are deleted when the app is uninstalled.',
        'Nasa phone lamang kung saan ito ginawa ang account. Hindi ito mababawi nang walang '
            'recovery code, at nabubura ito kapag in-uninstall ang app.',
      ),
    ),
    (
      _t('Limitation of liability', 'Limitasyon ng pananagutan'),
      _t(
        'The researchers are not responsible for losses that result from relying on a '
            'classification. Report scams to your bank or e-wallet and to the proper authorities.',
        'Hindi mananagot ang mga mananaliksik sa anumang pagkalugi dahil sa pag-asa sa isang '
            'resulta. I-report ang scam sa iyong bangko o e-wallet at sa kinauukulang awtoridad.',
      ),
    ),
    (
      _t('Changes', 'Mga pagbabago'),
      _t(
        'These terms may be updated in later versions of the app. Continuing to use the app '
            'means you accept the current terms.',
        'Maaaring baguhin ang mga tuntuning ito sa mga susunod na bersyon ng app. Ang patuloy na '
            'paggamit ng app ay nangangahulugang tinatanggap mo ang kasalukuyang mga tuntunin.',
      ),
    ),
  ];
}
