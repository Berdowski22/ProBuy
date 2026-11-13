import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class _ReviewDialogState extends State<ReviewDialog> {
  int _rating = 0;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ürünü Değerlendir'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.productName,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 34,
                    onPressed: () => setState(() => _rating = i),
                    icon: Icon(
                      i <= _rating ? Icons.star : Icons.star_border,
                      color: AppColors.buy,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _comment,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Yorumunuz (isteğe bağlı)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _rating == 0
              ? null
              : () => Navigator.pop(
                  context, (rating: _rating, comment: _comment.text.trim())),
          child: const Text('Gönder'),
        ),
      ],
    );
  }
}

class ReviewDialog extends StatefulWidget {
  final String productName;

  const ReviewDialog({super.key, required this.productName});

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}
