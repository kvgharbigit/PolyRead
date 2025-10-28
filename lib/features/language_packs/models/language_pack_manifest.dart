// Language Pack Manifest - Metadata for downloadable language packs
// Contains dictionary files, ML Kit models, and configuration

class LanguagePackManifest {
  final String id;
  final String name;
  final String language;
  final String version;
  final String description;
  final int totalSize;
  final List<LanguagePackFile> files;
  final List<String> supportedTargetLanguages;
  final DateTime releaseDate;
  final String? author;
  final String? license;
  final Map<String, dynamic> metadata;
  
  const LanguagePackManifest({
    required this.id,
    required this.name,
    required this.language,
    required this.version,
    required this.description,
    required this.totalSize,
    required this.files,
    required this.supportedTargetLanguages,
    required this.releaseDate,
    this.author,
    this.license,
    this.metadata = const {},
  });
  
  /// Create manifest from JSON
  factory LanguagePackManifest.fromJson(Map<String, dynamic> json) {
    return LanguagePackManifest(
      id: json['id'] as String,
      name: json['name'] as String,
      language: json['language'] as String,
      version: json['version'] as String,
      description: json['description'] as String,
      totalSize: json['total_size'] as int,
      files: (json['files'] as List<dynamic>)
          .map((file) => LanguagePackFile.fromJson(file as Map<String, dynamic>))
          .toList(),
      supportedTargetLanguages: (json['supported_target_languages'] as List<dynamic>)
          .cast<String>(),
      releaseDate: DateTime.parse(json['release_date'] as String),
      author: json['author'] as String?,
      license: json['license'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }
  
  /// Convert manifest to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'language': language,
      'version': version,
      'description': description,
      'total_size': totalSize,
      'files': files.map((file) => file.toJson()).toList(),
      'supported_target_languages': supportedTargetLanguages,
      'release_date': releaseDate.toIso8601String(),
      'author': author,
      'license': license,
      'metadata': metadata,
    };
  }
  
  /// Get formatted size string
  String get formattedSize {
    if (totalSize < 1024) return '${totalSize}B';
    if (totalSize < 1024 * 1024) return '${(totalSize / 1024).toStringAsFixed(1)}KB';
    return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
  
  /// Get dictionary files only
  List<LanguagePackFile> get dictionaryFiles {
    return files.where((file) => file.type == LanguagePackFileType.dictionary).toList();
  }
  
  /// Get ML Kit model files only
  List<LanguagePackFile> get modelFiles {
    return files.where((file) => file.type == LanguagePackFileType.mlModel).toList();
  }
  
  /// Check if pack supports a target language
  bool supportsTargetLanguage(String targetLanguage) {
    return supportedTargetLanguages.contains(targetLanguage);
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LanguagePackManifest &&
        other.id == id &&
        other.version == version;
  }
  
  @override
  int get hashCode => id.hashCode ^ version.hashCode;
}

class LanguagePackFile {
  final String name;
  final String path;
  final LanguagePackFileType type;
  final int size;
  final String checksum;
  final String downloadUrl;
  final bool required;
  final Map<String, dynamic> metadata;
  
  const LanguagePackFile({
    required this.name,
    required this.path,
    required this.type,
    required this.size,
    required this.checksum,
    required this.downloadUrl,
    this.required = true,
    this.metadata = const {},
  });
  
  factory LanguagePackFile.fromJson(Map<String, dynamic> json) {
    return LanguagePackFile(
      name: json['name'] as String,
      path: json['path'] as String,
      type: LanguagePackFileType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => LanguagePackFileType.other,
      ),
      size: json['size'] as int,
      checksum: json['checksum'] as String,
      downloadUrl: json['download_url'] as String,
      required: json['required'] as bool? ?? true,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'type': type.name,
      'size': size,
      'checksum': checksum,
      'download_url': downloadUrl,
      'required': required,
      'metadata': metadata,
    };
  }
  
  String get formattedSize {
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

enum LanguagePackFileType {
  dictionary,
  mlModel,
  configuration,
  other,
}

/// Represents a language pack installation
class LanguagePackInstallation {
  final String packId;
  final String version;
  final DateTime installedAt;
  final DateTime lastUsed;
  final PackInstallationStatus status;
  final List<String> installedFiles;
  final int totalSize;
  
  const LanguagePackInstallation({
    required this.packId,
    required this.version,
    required this.installedAt,
    required this.lastUsed,
    required this.status,
    required this.installedFiles,
    required this.totalSize,
  });
  
  factory LanguagePackInstallation.fromMap(Map<String, dynamic> map) {
    return LanguagePackInstallation(
      packId: map['pack_id'] as String,
      version: map['version'] as String,
      installedAt: DateTime.fromMillisecondsSinceEpoch(map['installed_at'] as int),
      lastUsed: DateTime.fromMillisecondsSinceEpoch(map['last_used'] as int),
      status: PackInstallationStatus.values.firstWhere(
        (status) => status.name == map['status'],
        orElse: () => PackInstallationStatus.unknown,
      ),
      installedFiles: (map['installed_files'] as String).split(','),
      totalSize: map['total_size'] as int,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'pack_id': packId,
      'version': version,
      'installed_at': installedAt.millisecondsSinceEpoch,
      'last_used': lastUsed.millisecondsSinceEpoch,
      'status': status.name,
      'installed_files': installedFiles.join(','),
      'total_size': totalSize,
    };
  }
}

enum PackInstallationStatus {
  installing,
  installed,
  updateAvailable,
  corrupted,
  unknown,
}