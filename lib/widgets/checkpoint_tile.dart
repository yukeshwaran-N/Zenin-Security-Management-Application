import 'package:flutter/material.dart';
import '../models/checkpoint_model.dart';

class CheckpointTile extends StatelessWidget {
  final Checkpoint checkpoint;
  final VoidCallback onTap;

  const CheckpointTile({
    super.key,
    required this.checkpoint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: checkpoint.isCompleted ? 1 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: checkpoint.isCompleted
            ? BorderSide(color: Colors.green.shade200)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _getStatusColor().withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getStatusIcon(),
            color: _getStatusColor(),
          ),
        ),
        title: Text(
          checkpoint.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              checkpoint.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.checklist,
                  size: 14,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  '${checkpoint.checklist.length} items',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.location_on,
                  size: 14,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  '${checkpoint.radius}m radius',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (checkpoint.isCompleted) ...[
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 28,
              ),
              const SizedBox(height: 2),
              Text(
                'Completed',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.green.shade700,
                ),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: const Size(80, 36),
                ),
                child: const Text('Verify'),
              ),
            ]
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Color _getStatusColor() {
    if (checkpoint.isCompleted) {
      return Colors.green;
    }
    return Colors.orange;
  }

  IconData _getStatusIcon() {
    if (checkpoint.isCompleted) {
      return Icons.check_circle;
    }
    return Icons.pending;
  }
}
