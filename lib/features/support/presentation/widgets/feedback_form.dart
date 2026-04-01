import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../blocs/support_bloc.dart';
import '../../domain/entities/feedback_ticket.dart';
import 'diagnostics_preview.dart';
import 'package:omni_bridge/core/widgets/omni_tinted_button.dart';
import 'package:omni_bridge/core/widgets/omni_segmented_control.dart';

class FeedbackForm extends StatefulWidget {
  const FeedbackForm({super.key});

  @override
  State<FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<FeedbackForm> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SupportBloc, SupportState>(
      builder: (context, state) {
        if (state.isSubmitted) {
          return _buildSuccessState(context);
        }
        return _buildForm(context, state);
      },
    );
  }

  Widget _buildSuccessState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: AppShapes.xl,
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.accentCyan.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accentCyan.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 36,
              color: AppColors.accentCyan,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Request Submitted',
            style: AppTextStyles.title.copyWith(
              color: AppColors.offWhite,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Our team will get back to you shortly.\nCheck the sidebar to track your ticket.',
            style: AppTextStyles.body.copyWith(color: AppColors.white54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          OmniTintedButton(
            label: 'Send Another',
            icon: Icons.add_comment_outlined,
            color: AppColors.accentCyan,
            onPressed: () {
              _subjectController.clear();
              _messageController.clear();
              context.read<SupportBloc>().add(const LoadSupportLinks());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context, SupportState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section Header ───────────────────────────────────────────
        Row(
          children: [
            Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.accentCyan,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'NEW TICKET',
              style: AppTextStyles.labelTiny.copyWith(
                color: AppColors.accentCyan,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Type Selector Pills ───────────────────────────────────────
        OmniSegmentedControl<FeedbackType>(
          value: state.feedbackType,
          color: AppColors.accentCyan,
          onChanged: (type) =>
              context.read<SupportBloc>().add(UpdateFeedbackType(type)),
          segments: const [
            OmniSegment(
              value: FeedbackType.support,
              label: 'Support',
              icon: Icons.support_agent_outlined,
            ),
            OmniSegment(
              value: FeedbackType.bug,
              label: 'Bug Report',
              icon: Icons.bug_report_outlined,
            ),
            OmniSegment(
              value: FeedbackType.feature,
              label: 'Feature',
              icon: Icons.lightbulb_outline_rounded,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Subject Field ─────────────────────────────────────────────
        _OmniTextField(
          controller: _subjectController,
          label: 'Subject',
          hint: 'Brief summary of your issue...',
          icon: Icons.title_rounded,
          onChanged: (val) =>
              context.read<SupportBloc>().add(UpdateFeedbackSubject(val)),
        ),
        const SizedBox(height: 16),

        // ── Message Field ─────────────────────────────────────────────
        _OmniTextField(
          controller: _messageController,
          label: 'Description',
          hint: 'Describe your issue or suggestion in detail...',
          icon: Icons.article_outlined,
          maxLines: 6,
          onChanged: (val) =>
              context.read<SupportBloc>().add(UpdateFeedbackMessage(val)),
        ),
        const SizedBox(height: 24),

        // ── Attachments ───────────────────────────────────────────────
        Row(
          children: [
            const Icon(
              Icons.attach_file_rounded,
              size: 14,
              color: AppColors.white54,
            ),
            const SizedBox(width: 8),
            Text(
              'Attachments',
              style: AppTextStyles.caption.copyWith(color: AppColors.white54),
            ),
            const Spacer(),
            _GhostButton(
              label: 'Add Files',
              icon: Icons.upload_file_outlined,
              onTap: () async {
                final bloc = context.read<SupportBloc>();
                final result = await FilePicker.platform.pickFiles(
                  allowMultiple: true,
                );
                if (result != null) {
                  for (final path in result.paths) {
                    if (path != null) bloc.add(AddAttachment(File(path)));
                  }
                }
              },
            ),
          ],
        ),
        if (state.attachments.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: state.attachments.asMap().entries.map((entry) {
              final name = entry.value.path.split(Platform.pathSeparator).last;
              return _AttachmentChip(
                name: name,
                onRemove: () => context.read<SupportBloc>().add(
                  RemoveAttachment(entry.key),
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 24),

        // ── Diagnostics ───────────────────────────────────────────────
        DiagnosticsPreview(snapshot: state.systemSnapshot),
        const SizedBox(height: 24),

        // ── Submit Button ─────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OmniTintedButton(
            isLoading: state.isSubmitting,
            label: state.feedbackType == FeedbackType.support
                ? 'Submit Support Request'
                : 'Submit Feedback',
            icon: Icons.send_rounded,
            color: AppColors.accentCyan,
            onPressed:
                (state.subject.isEmpty ||
                    state.message.isEmpty ||
                    state.isSubmitting)
                ? null
                : () => context.read<SupportBloc>().add(const SubmitFeedback()),
          ),
        ),
        if (state.error != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 14,
                color: AppColors.accentRed,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  state.error!,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.accentRed,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _OmniTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final ValueChanged<String> onChanged;

  const _OmniTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.onChanged,
    this.maxLines = 1,
  });

  @override
  State<_OmniTextField> createState() => _OmniTextFieldState();
}

class _OmniTextFieldState extends State<_OmniTextField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              widget.icon,
              size: 13,
              color: _focused ? AppColors.accentCyan : AppColors.white54,
            ),
            const SizedBox(width: 6),
            Text(
              widget.label.toUpperCase(),
              style: AppTextStyles.labelTiny.copyWith(
                color: _focused ? AppColors.accentCyan : AppColors.white54,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                fontSize: 9,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _focused ? 0.04 : 0.02),
            borderRadius: AppShapes.md,
            border: Border.all(
              color: _focused
                  ? AppColors.accentCyan.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.08),
              width: _focused ? 1.5 : 1,
            ),
          ),
          child: Focus(
            onFocusChange: (v) => setState(() => _focused = v),
            child: TextField(
              controller: widget.controller,
              onChanged: widget.onChanged,
              maxLines: widget.maxLines,
              style: AppTextStyles.body.copyWith(color: AppColors.offWhite),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: AppTextStyles.body.copyWith(
                  color: AppColors.white54.withValues(alpha: 0.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GhostButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _GhostButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.accentCyan.withValues(alpha: 0.06),
          borderRadius: AppShapes.md,
          border: Border.all(
            color: AppColors.accentCyan.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.accentCyan),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.accentCyan,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  final String name;
  final VoidCallback onRemove;

  const _AttachmentChip({required this.name, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: AppShapes.md,
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.insert_drive_file_outlined,
            size: 12,
            color: AppColors.accentCyan,
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              name,
              style: AppTextStyles.labelTiny.copyWith(
                color: AppColors.offWhite,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close_rounded,
              size: 12,
              color: AppColors.white54.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
