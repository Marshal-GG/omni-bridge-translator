import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/support_bloc.dart';
import '../../domain/entities/feedback_ticket.dart';
import 'diagnostics_preview.dart';

class FeedbackForm extends StatefulWidget {
  const FeedbackForm({super.key});

  @override
  State<FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<FeedbackForm> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SupportBloc, SupportState>(
      builder: (context, state) {
        if (state.isSubmitted) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 48),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline, size: 48, color: Colors.greenAccent),
                const SizedBox(height: 16),
                const Text(
                  'Feedback Sent!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Thank you for helping us improve OmniBridge.',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    context.read<SupportBloc>().add(const LoadSupportLinks()); // Reset state
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Send Another'),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type Selector
              Row(
                children: FeedbackType.values.map((type) {
                  final isSelected = state.feedbackType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(type.name.toUpperCase()),
                      selected: isSelected,
                      onSelected: (_) => context.read<SupportBloc>().add(UpdateFeedbackType(type)),
                      selectedColor: Colors.cyanAccent.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.cyanAccent : Colors.white38,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Subject
              TextField(
                onChanged: (val) => context.read<SupportBloc>().add(UpdateFeedbackSubject(val)),
                decoration: const InputDecoration(
                  hintText: 'Subject',
                ),
              ),
              const SizedBox(height: 24),

              // Message
              TextField(
                onChanged: (val) => context.read<SupportBloc>().add(UpdateFeedbackMessage(val)),
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Describe your issue or suggestion...',
                ),
              ),
              const SizedBox(height: 32),

              // Attachments
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Attachments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  TextButton.icon(
                    onPressed: () async {
                      final bloc = context.read<SupportBloc>();
                      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
                      if (result != null) {
                        for (final path in result.paths) {
                          if (path != null) {
                            bloc.add(AddAttachment(File(path)));
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.attach_file, size: 16),
                    label: const Text('Add Files'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (state.attachments.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: state.attachments.asMap().entries.map((entry) {
                    return Chip(
                      label: Text(
                        entry.value.path.split(Platform.pathSeparator).last,
                        style: const TextStyle(fontSize: 10),
                      ),
                      onDeleted: () => context.read<SupportBloc>().add(RemoveAttachment(entry.key)),
                      deleteIcon: const Icon(Icons.close, size: 14),
                    );
                  }).toList(),
                ),
              
              const SizedBox(height: 32),
              DiagnosticsPreview(snapshot: state.systemSnapshot),
              
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: (state.subject.isEmpty || state.message.isEmpty || state.isSubmitting)
                      ? null
                      : () => context.read<SupportBloc>().add(const SubmitFeedback()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.white12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: state.isSubmitting
                      ? const SizedBox(
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : Text(
                      state.feedbackType == FeedbackType.support 
                          ? 'Submit Support Request' 
                          : 'Submit Feedback', 
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                ),
              ),
              if (state.error != null) ...[
                const SizedBox(height: 12),
                Text(state.error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ],
          ),
        );
      },
    );
  }
}

