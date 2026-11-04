import 'package:creatorconnect/services/connection_request_service.dart';
import 'package:flutter/material.dart';

class RemoveConnectionButton extends StatefulWidget {
  final String currentUid;
  final String otherUid;
  final VoidCallback? onRemoved;

  const RemoveConnectionButton({
    super.key,
    required this.currentUid,
    required this.otherUid,
    this.onRemoved,
  });

  @override
  State<RemoveConnectionButton> createState() => _RemoveConnectionButtonState();
}

class _RemoveConnectionButtonState extends State<RemoveConnectionButton> {
  bool _isRemoving = false;

  Future<void> _confirmAndRemove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove connection?'),
        content: const Text(
          'This removes the connection and conversation for both users. '
          'The profile will be available again in Explore Profiles.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isRemoving = true);
    try {
      await ConnectionRequestService.removeConnection(
        currentUid: widget.currentUid,
        otherUid: widget.otherUid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Connection removed.')));
      widget.onRemoved?.call();
    } catch (error) {
      debugPrint('Unable to remove connection: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove connection: $error')),
      );
    } finally {
      if (mounted) setState(() => _isRemoving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentUid.isEmpty ||
        widget.otherUid.isEmpty ||
        widget.currentUid == widget.otherUid) {
      return const SizedBox.shrink();
    }

    return IconButton(
      tooltip: 'Remove connection',
      onPressed: _isRemoving ? null : _confirmAndRemove,
      icon: _isRemoving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.person_remove_alt_1_outlined),
    );
  }
}
