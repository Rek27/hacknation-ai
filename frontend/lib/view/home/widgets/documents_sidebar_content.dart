import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/config/app_constants.dart';
import 'package:frontend/view/home/home_controller.dart';

/// Reusable documents list with refresh and upload. Used in desktop sidebar and mobile drawer.
class DocumentsSidebarContent extends StatelessWidget {
  const DocumentsSidebarContent({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeController controller = context.watch<HomeController>();
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: Text(
            'Documents',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.refreshDocuments,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
          ),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload'),
            onPressed: () => _pickAndUpload(context),
          ),
        ),
        const SizedBox(height: AppConstants.spacingSm),
        Expanded(
          child: controller.loadingDocs
              ? Center(
                  child: CircularProgressIndicator(color: colorScheme.primary),
                )
              : ListView.builder(
                  itemCount: controller.documents.length,
                  itemBuilder: (BuildContext context, int index) {
                    final doc = controller.documents[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        doc.filename,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium,
                      ),
                      subtitle: Text(
                        '${doc.chunks} chunks',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: colorScheme.error),
                        onPressed: () => controller.deleteDoc(doc.filename),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _pickAndUpload(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'pdf'],
    );
    if (result != null && result.files.single.path != null && context.mounted) {
      final controller = context.read<HomeController>();
      await controller.upload(File(result.files.single.path!));
    }
  }
}
