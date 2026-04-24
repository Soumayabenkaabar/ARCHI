class Model3D {
  final String id;
  final String projectId;
  final String url;
  final List<String> meshNames;
  final String createdAt;

  const Model3D({
    required this.id,
    required this.projectId,
    required this.url,
    required this.meshNames,
    this.createdAt = '',
  });

  factory Model3D.fromJson(Map<String, dynamic> j) => Model3D(
    id: j['id']?.toString() ?? '',
    projectId: j['project_id']?.toString() ?? '',
    url: j['url'] as String? ?? '',
    meshNames: List<String>.from(j['mesh_names'] ?? []),
    createdAt: j['created_at']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {
    'project_id': projectId,
    'url': url,
    'mesh_names': meshNames,
  };
}
