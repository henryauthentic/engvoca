import 'package:flutter/material.dart';
import '../services/feedback_service.dart';

class FeedbackDialog extends StatefulWidget {
  final String? initialType; // 'bug', 'suggestion', 'wrong_word', 'other'
  final String? wordId;
  final String? wordText;

  const FeedbackDialog({
    super.key,
    this.initialType,
    this.wordId,
    this.wordText,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialType,
    String? wordId,
    String? wordText,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FeedbackDialog(
        initialType: initialType,
        wordId: wordId,
        wordText: wordText,
      ),
    );
  }

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _feedbackService = FeedbackService();

  String _selectedType = 'bug';
  bool _isLoading = false;

  final Map<String, String> _typeLabels = {
    'bug': 'Báo lỗi ứng dụng',
    'suggestion': 'Góp ý / Đề xuất',
    'wrong_word': 'Báo cáo sai từ vựng',
    'other': 'Khác',
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null && _typeLabels.containsKey(widget.initialType)) {
      _selectedType = widget.initialType!;
    }
    
    if (_selectedType == 'wrong_word' && widget.wordText != null) {
      _subjectController.text = 'Sai thông tin từ: ${widget.wordText}';
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _feedbackService.submitFeedback(
        type: _selectedType,
        subject: _subjectController.text.trim(),
        message: _messageController.text.trim(),
        wordId: widget.wordId,
        wordText: widget.wordText,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cảm ơn bạn đã gửi phản hồi!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Để bottom sheet nâng lên khi bàn phím xuất hiện
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Gửi Phản Hồi',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Chủ đề',
                border: OutlineInputBorder(),
              ),
              items: _typeLabels.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (widget.initialType == 'wrong_word') 
                ? null // Khóa không cho sửa nếu đang báo cáo sai từ
                : (value) {
                  if (value != null) setState(() => _selectedType = value);
                },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Tiêu đề',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value!.isEmpty ? 'Vui lòng nhập tiêu đề' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _messageController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Nội dung chi tiết',
                hintText: _selectedType == 'wrong_word' 
                  ? 'Vui lòng cho biết từ này sai nghĩa, sai phiên âm, hay sai ngữ pháp?' 
                  : 'Mô tả chi tiết vấn đề bạn gặp phải...',
                border: const OutlineInputBorder(),
              ),
              validator: (value) => value!.isEmpty ? 'Vui lòng nhập nội dung' : null,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Gửi',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
