import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void showInstructionsBottomSheet(BuildContext context) {
  final instructions = [
    _Instruction(
      icon: Icons.waving_hand,
      title: AppLocalizations.of(context)!.welcomeTitle,
      content: AppLocalizations.of(context)!.welcomeContent,
      isWelcome: true,
    ),
    _Instruction(
      icon: Icons.sports_soccer,
      title: AppLocalizations.of(context)!.guessTitle,
      content: AppLocalizations.of(context)!.guessContent,
      isWelcome: false,
    ),
    _Instruction(
      icon: Icons.emoji_events,
      title: AppLocalizations.of(context)!.winnerTitle,
      content: AppLocalizations.of(context)!.winnerContent,
      isWelcome: false,
    ),
    _Instruction(
      icon: Icons.sports,
      title: AppLocalizations.of(context)!.topScorerTitle,
      content: AppLocalizations.of(context)!.topScorerContent,
      isWelcome: false,
    ),
    _Instruction(
      icon: Icons.stacked_line_chart,
      title: AppLocalizations.of(context)!.scoringTitle,
      content: AppLocalizations.of(context)!.scoringContent,
      isWelcome: false,
    ),
    _Instruction(
      icon: Icons.groups,
      title: AppLocalizations.of(context)!.groupsTitle,
      content: AppLocalizations.of(context)!.groupsContent,
      isWelcome: false,
    ),
    _Instruction(
      icon: Icons.lock_clock,
      title: AppLocalizations.of(context)!.guessDeadlineTitle,
      content: AppLocalizations.of(context)!.guessDeadlineContent,
      isWelcome: false,
    ),
    // _Instruction(
    //   icon: Icons.warning_amber,
    //   title: AppLocalizations.of(context)!.importantNoteTitle,
    //   content: AppLocalizations.of(context)!.importantNoteContent,
    //   isWelcome: false,
    // ),
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (context) {
      return _InstructionsBottomSheet(instructions: instructions);
    },
  );
}

class _InstructionsBottomSheet extends StatefulWidget {
  final List<_Instruction> instructions;
  const _InstructionsBottomSheet({required this.instructions});

  @override
  State<_InstructionsBottomSheet> createState() =>
      _InstructionsBottomSheetState();
}

class _InstructionsBottomSheetState extends State<_InstructionsBottomSheet>
    with TickerProviderStateMixin {
  int _currentPage = 0;
  late PageController _controller;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _fadeAnimation.value) * 100),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              height: size.height * 0.75,
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildHeader(context),
                  _buildPageView(context),
                  _buildIndicators(context),
                  _buildNavigationBar(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Text(
              //   'מדריך לשימוש',
              //   style: TextStyle(
              //     fontSize: 24,
              //     fontWeight: FontWeight.bold,
              //     color: Theme.of(context).primaryColor,
              //   ),
              // ),
              // IconButton(
              //   onPressed: () => Navigator.pop(context),
              //   icon: Icon(Icons.close, color: Colors.grey[600]),
              //   style: IconButton.styleFrom(
              //     backgroundColor: Colors.grey[100],
              //     shape: CircleBorder(),
              //   ),
              // ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageView(BuildContext context) {
    return Expanded(
      child: PageView.builder(
        controller: _controller,
        itemCount: widget.instructions.length,
        onPageChanged: (i) => setState(() => _currentPage = i),
        itemBuilder: (context, i) =>
            _buildInstructionCard(widget.instructions[i], context),
      ),
    );
  }

  Widget _buildInstructionCard(_Instruction instruction, BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: instruction.isWelcome
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.primaryColor.withOpacity(0.1),
                  theme.primaryColor.withOpacity(0.05),
                ],
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(0),
                decoration: BoxDecoration(
                  color: instruction.isWelcome
                      ? theme.primaryColor
                      : theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                // child: Icon(
                //   instruction.icon,
                //   size: 32,
                //   color:
                //       instruction.isWelcome ? Colors.white : Colors.white,
                // ),
              ),
              // SizedBox(width: 16),
              SizedBox(height: 32),
              Expanded(
                child: Text(
                  instruction.title,
                  textAlign: TextAlign.center, // ⬅️ Center the text
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 40),
          Text(
            instruction.content,
            textAlign: TextAlign.center, // ⬅️ Center the text
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
            ),
          ),
          // if (instruction.isWelcome) ...[
          //   SizedBox(height: 24),
          //   Container(
          //     padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          //     decoration: BoxDecoration(
          //       color: theme.primaryColor.withOpacity(0.1),
          //       borderRadius: BorderRadius.circular(12),
          //       border: Border.all(
          //         color: theme.primaryColor.withOpacity(0.3),
          //       ),
          //     ),
          //     child: Row(
          //       children: [
          //         Icon(
          //           Icons.info_outline,
          //           size: 20,
          //           color: theme.primaryColor,
          //         ),
          //         SizedBox(width: 8),
          //         Expanded(
          //           child: Text(
          //             'החלק שמאלה כדי לקרוא את ההוראות',
          //             style: TextStyle(
          //               fontSize: 14,
          //               color: theme.primaryColor,
          //               fontWeight: FontWeight.w500,
          //             ),
          //           ),
          //         ),
          //       ],
          //     ),
          //   ),
          // ],
        ],
      ),
    );
  }

  Widget _buildIndicators(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lightBlue = Color(0xFF28c2ff);
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          widget.instructions.length,
          (i) => AnimatedContainer(
            duration: Duration(milliseconds: 300),
            margin: EdgeInsets.symmetric(horizontal: 4),
            width: i == _currentPage ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: i == _currentPage
                  ? (isDark ? lightBlue : Theme.of(context).primaryColor)
                  : (isDark ? lightBlue.withOpacity(0.3) : Colors.grey[300]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lightBlue = Colors.blue;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavigationButton(
            icon: Icons.arrow_back_ios,
            onPressed: _currentPage > 0 ? _previousPage : null,
            isEnabled: _currentPage > 0,
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? lightBlue.withOpacity(0.15)
                  : Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_currentPage + 1} ${AppLocalizations.of(context)!.from} ${widget.instructions.length}',
              style: TextStyle(
                color: isDark ? lightBlue : Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          _buildNavigationButton(
            icon: Icons.arrow_forward_ios,
            onPressed: _currentPage < widget.instructions.length - 1
                ? _nextPage
                : null,
            isEnabled: _currentPage < widget.instructions.length - 1,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isEnabled,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lightBlue = Colors.blue;
    ;
    return Container(
      decoration: BoxDecoration(
        color: isEnabled
            ? (isDark ? lightBlue : Theme.of(context).primaryColor)
            : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: isEnabled
              ? (isDark ? Colors.white : Colors.white)
              : Colors.grey[400],
          size: 20,
        ),
      ),
    );
  }

  void _previousPage() {
    _controller.previousPage(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _nextPage() {
    _controller.nextPage(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}

class _Instruction {
  final IconData icon;
  final String title;
  final String content;
  final bool isWelcome;

  _Instruction({
    required this.icon,
    required this.title,
    required this.content,
    required this.isWelcome,
  });
}
