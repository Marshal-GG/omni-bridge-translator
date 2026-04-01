import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../../../core/theme/app_theme.dart';
import '../blocs/support_bloc.dart';

class ChatInputWidget extends StatefulWidget {
  const ChatInputWidget({super.key});

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSubmitted() {
    final text = _controller.text.trim();
    final state = context.read<SupportBloc>().state;
    if (text.isNotEmpty || state.chatAttachments.isNotEmpty) {
      context.read<SupportBloc>().add(SendMessage(text: text));
      _controller.clear();
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null && mounted) {
      for (final path in result.paths) {
        if (path != null) {
          context.read<SupportBloc>().add(AddChatAttachment(File(path)));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SupportBloc, SupportState>(
      builder: (context, state) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.chatAttachments.isNotEmpty)
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: state.chatAttachments.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final file = state.chatAttachments[index];
                    return _buildAttachmentPreview(context, file, index);
                  },
                ),
              ),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: const BoxDecoration(
                color: Color(0x05FFFFFF), // white 0.02
                border: Border(top: BorderSide(color: AppColors.white10)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.attach_file,
                      size: 20,
                      color: AppColors.white38,
                    ),
                    onPressed: _pickFile,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: AppTextStyles.body,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: AppTextStyles.body.copyWith(
                          color: AppColors.whiteOpacity(0.2),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: AppShapes.round,
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppColors.whiteOpacity(0.05),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _handleSubmitted(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.send,
                      size: 20,
                      color: state.isSendingMessage
                          ? AppColors.white24
                          : AppColors.accentCyan,
                    ),
                    onPressed: state.isSendingMessage ? null : _handleSubmitted,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAttachmentPreview(BuildContext context, File file, int index) {
    final fileName = p.basename(file.path);
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.whiteOpacity(0.05),
        borderRadius: AppShapes.md,
        border: Border.all(color: AppColors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file, size: 16, color: Colors.white38),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              fileName,
              style: AppTextStyles.labelTiny,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: () =>
                context.read<SupportBloc>().add(RemoveChatAttachment(index)),
            child: const Icon(
              Icons.close,
              size: 14,
              color: AppColors.accentRed,
            ),
          ),
        ],
      ),
    );
  }
}
