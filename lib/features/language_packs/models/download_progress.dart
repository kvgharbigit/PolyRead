// Download Progress model for tracking language pack downloads

class DownloadProgress {
  final String packId;
  final String packName;
  final DownloadStatus status;
  final int downloadedBytes;
  final int totalBytes;
  final double progressPercent;
  final String? currentFile;
  final int filesCompleted;
  final int totalFiles;
  final String? error;
  final DateTime startTime;
  final DateTime? endTime;
  
  const DownloadProgress({
    required this.packId,
    required this.packName,
    required this.status,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.progressPercent,
    this.currentFile,
    required this.filesCompleted,
    required this.totalFiles,
    this.error,
    required this.startTime,
    this.endTime,
  });
  
  /// Create initial download progress
  factory DownloadProgress.initial({
    required String packId,
    required String packName,
    required int totalBytes,
    required int totalFiles,
  }) {
    return DownloadProgress(
      packId: packId,
      packName: packName,
      status: DownloadStatus.pending,
      downloadedBytes: 0,
      totalBytes: totalBytes,
      progressPercent: 0.0,
      filesCompleted: 0,
      totalFiles: totalFiles,
      startTime: DateTime.now(),
    );
  }
  
  /// Update progress with new values
  DownloadProgress copyWith({
    DownloadStatus? status,
    int? downloadedBytes,
    int? totalBytes,
    String? currentFile,
    int? filesCompleted,
    String? error,
    DateTime? endTime,
  }) {
    final newDownloadedBytes = downloadedBytes ?? this.downloadedBytes;
    final newTotalBytes = totalBytes ?? this.totalBytes;
    final newProgressPercent = newTotalBytes > 0 
        ? (newDownloadedBytes / newTotalBytes) * 100 
        : 0.0;
    
    return DownloadProgress(
      packId: packId,
      packName: packName,
      status: status ?? this.status,
      downloadedBytes: newDownloadedBytes,
      totalBytes: newTotalBytes,
      progressPercent: newProgressPercent,
      currentFile: currentFile ?? this.currentFile,
      filesCompleted: filesCompleted ?? this.filesCompleted,
      totalFiles: totalFiles,
      error: error ?? this.error,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
    );
  }
  
  /// Create progress update for specific file
  DownloadProgress updateFileProgress({
    required String fileName,
    required int fileDownloadedBytes,
    required int fileTotalBytes,
  }) {
    // Calculate overall progress including this file
    final baseProgress = (filesCompleted / totalFiles) * totalBytes;
    final fileProgress = (fileDownloadedBytes / fileTotalBytes) * (totalBytes / totalFiles);
    final newDownloadedBytes = (baseProgress + fileProgress).round();
    
    return copyWith(
      downloadedBytes: newDownloadedBytes,
      currentFile: fileName,
    );
  }
  
  /// Mark file as completed
  DownloadProgress completeFile() {
    return copyWith(
      filesCompleted: filesCompleted + 1,
      currentFile: null,
    );
  }
  
  /// Mark download as completed
  DownloadProgress complete() {
    return copyWith(
      status: DownloadStatus.completed,
      downloadedBytes: totalBytes,
      filesCompleted: totalFiles,
      currentFile: null,
      endTime: DateTime.now(),
    );
  }
  
  /// Mark download as failed
  DownloadProgress fail(String errorMessage) {
    return copyWith(
      status: DownloadStatus.failed,
      error: errorMessage,
      endTime: DateTime.now(),
    );
  }
  
  /// Mark download as cancelled
  DownloadProgress cancel() {
    return copyWith(
      status: DownloadStatus.cancelled,
      endTime: DateTime.now(),
    );
  }
  
  /// Get formatted download speed (if applicable)
  String? get downloadSpeed {
    if (status != DownloadStatus.downloading) return null;
    
    final elapsed = DateTime.now().difference(startTime);
    if (elapsed.inSeconds == 0) return null;
    
    final bytesPerSecond = downloadedBytes / elapsed.inSeconds;
    if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
  
  /// Get estimated time remaining
  String? get estimatedTimeRemaining {
    if (status != DownloadStatus.downloading || progressPercent <= 0) return null;
    
    final elapsed = DateTime.now().difference(startTime);
    final totalEstimated = elapsed.inSeconds * (100 / progressPercent);
    final remaining = totalEstimated - elapsed.inSeconds;
    
    if (remaining < 60) return '${remaining.round()}s';
    if (remaining < 3600) return '${(remaining / 60).round()}m';
    return '${(remaining / 3600).round()}h';
  }
  
  /// Get formatted size strings
  String get formattedProgress {
    return '${_formatBytes(downloadedBytes)} / ${_formatBytes(totalBytes)}';
  }
  
  bool get isActive => status == DownloadStatus.downloading || status == DownloadStatus.pending;
  bool get isCompleted => status == DownloadStatus.completed;
  bool get isFailed => status == DownloadStatus.failed;
  bool get isCancelled => status == DownloadStatus.cancelled;
  
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

enum DownloadStatus {
  pending,
  downloading,
  completed,
  failed,
  cancelled,
  paused,
}

/// Represents storage quota management
class StorageQuota {
  final int totalLimitBytes;
  final int currentUsageBytes;
  final int availableBytes;
  final Map<String, int> packUsage;
  
  const StorageQuota({
    required this.totalLimitBytes,
    required this.currentUsageBytes,
    required this.availableBytes,
    required this.packUsage,
  });
  
  factory StorageQuota.create({
    required int totalLimitBytes,
    required Map<String, int> packUsage,
  }) {
    final currentUsage = packUsage.values.fold(0, (sum, usage) => sum + usage);
    final available = totalLimitBytes - currentUsage;
    
    return StorageQuota(
      totalLimitBytes: totalLimitBytes,
      currentUsageBytes: currentUsage,
      availableBytes: available,
      packUsage: packUsage,
    );
  }
  
  bool canFit(int requiredBytes) => requiredBytes <= availableBytes;
  
  double get usagePercent => totalLimitBytes > 0 
      ? (currentUsageBytes / totalLimitBytes) * 100 
      : 0.0;
  
  String get formattedUsage {
    return '${_formatBytes(currentUsageBytes)} / ${_formatBytes(totalLimitBytes)}';
  }
  
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}