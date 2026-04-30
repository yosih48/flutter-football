import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';

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
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (ctx) {
      return _InstructionsBottomSheet(instructions: instructions);
    },
  );
}

// ── Bottom sheet ──────────────────────────────────────────────────────────
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
  late final PageController _controller;
  late final AnimationController _animController;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _animController.dispose();
    super.dispose();
  }

  bool get _isFirst => _currentPage == 0;
  bool get _isLast => _currentPage == widget.instructions.length - 1;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: _fade,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _fade.value) * 80),
          child: Opacity(
            opacity: _fade.value,
            child: Container(
              height: size.height * 0.75,
              decoration: BoxDecoration(
                color: c.card,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(2)),
              ),
              child: Column(
                children: [
                  _buildHandle(c),
                  _buildPageView(c),
                  _buildIndicators(c),
                  _buildNavBar(c),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Drag handle ──────────────────────────────────────────────────────────
  Widget _buildHandle(EditorialColors c) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Center(
        child: Container(
          width: 36,
          height: 3,
          decoration: BoxDecoration(
            color: c.hairlineHi,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  // ── Page view ────────────────────────────────────────────────────────────
  Widget _buildPageView(EditorialColors c) {
    return Expanded(
      child: PageView.builder(
        controller: _controller,
        itemCount: widget.instructions.length,
        onPageChanged: (i) => setState(() => _currentPage = i),
        itemBuilder: (context, i) =>
            _buildCard(widget.instructions[i], c),
      ),
    );
  }

  Widget _buildCard(_Instruction ins, EditorialColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon badge
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: ins.isWelcome ? c.live : c.liveSoft,
              shape: BoxShape.circle,
              border: Border.all(
                color: ins.isWelcome ? c.live : c.live.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              ins.icon,
              size: 26,
              color: ins.isWelcome ? c.pitch : c.live,
            ),
          ),

          const SizedBox(height: 28),

          // Title
          Text(
            ins.title,
            textAlign: TextAlign.center,
            style: EType.display(
              size: 22,
              color: c.ink,
              letterSpacing: 0.8,
              height: 1.15,
            ),
          ),

          const SizedBox(height: 16),

          // Accent line
          Container(
            width: 28,
            height: 2,
            color: c.live,
          ),

          const SizedBox(height: 20),

          // Body
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Text(
                ins.content,
                textAlign: TextAlign.center,
                style: EType.body(
                  color: c.inkMute,
                  size: 15,
                  height: 1.65,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Dot indicators ───────────────────────────────────────────────────────
  Widget _buildIndicators(EditorialColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          widget.instructions.length,
          (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == _currentPage ? 24 : 7,
            height: 7,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: i == _currentPage ? c.live : c.hairlineHi,
            ),
          ),
        ),
      ),
    );
  }

  // ── Navigation bar ───────────────────────────────────────────────────────
  Widget _buildNavBar(EditorialColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back arrow (invisible on first page to preserve layout)
          AnimatedOpacity(
            opacity: _isFirst ? 0 : 1,
            duration: const Duration(milliseconds: 180),
            child: _NavBtn(
              icon: Icons.arrow_back_ios_new,
              filled: false,
              c: c,
              onTap: _isFirst ? null : _prev,
            ),
          ),

          // Counter pill
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: c.liveSoft,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(
                  color: c.live.withOpacity(0.3), width: 1),
            ),
            child: Text(
              '${_currentPage + 1}  /  ${widget.instructions.length}',
              style: EType.label(
                color: c.live,
                size: 11,
                letterSpacing: 1.6,
              ),
            ),
          ),

          // Forward / Done button
          _NavBtn(
            icon: _isLast ? Icons.check : Icons.arrow_forward_ios,
            filled: true,
            c: c,
            onTap: _isLast ? () => Navigator.pop(context) : _next,
          ),
        ],
      ),
    );
  }

  void _prev() => _controller.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

  void _next() => _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
}

// ── Small icon button ─────────────────────────────────────────────────────
class _NavBtn extends StatelessWidget {
  const _NavBtn({
    required this.icon,
    required this.filled,
    required this.c,
    required this.onTap,
  });
  final IconData icon;
  final bool filled;
  final EditorialColors c;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: filled ? c.live : Colors.transparent,
          borderRadius: BorderRadius.circular(2),
          border: filled
              ? null
              : Border.all(color: c.hairline, width: 1),
        ),
        child: Icon(
          icon,
          size: 16,
          color: filled ? c.pitch : c.ink,
        ),
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────
class _Instruction {
  final IconData icon;
  final String title;
  final String content;
  final bool isWelcome;

  const _Instruction({
    required this.icon,
    required this.title,
    required this.content,
    required this.isWelcome,
  });
}
